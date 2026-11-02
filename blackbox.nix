{
  config,
  lib,
  pkgs,
  ...
}:
# Checks from the outside of each service: does its URL answer through Caddy,
# with a valid certificate, and does AdGuard answer DNS. Everything else in
# prometheus.nix is a service reporting on itself, which says nothing when the
# thing between it and the user is what broke.
#
# The targets are every vhost in the registry (./registry.nix), so a new service
# is probed as soon as it gets a URL. Probed from this box, they resolve as they
# do on the LAN: *.shlambert.top is the LAN address, and headscale is pinned to
# loopback by headscale.nix.
let
  port = config.services.prometheus.exporters.blackbox.port;

  vhosts = lib.filterAttrs (_: s: s.vhost) config.shlam.services;

  modules = {
    https = {
      prober = "http";
      timeout = "10s";
      http = {
        preferred_ip_protocol = "ip4";
        fail_if_not_ssl = true;
        # "Answers at all" rather than "returns 200": several services answer
        # their root with a login challenge or a redirect, and mushebrawl's
        # signaling server answers a plain GET with 400. What should fail is
        # Caddy's own 502/503/504 when the backend is gone.
        valid_status_codes = [
          200
          204
          301
          302
          303
          307
          308
          400
          401
          403
          404
          405
        ];
      };
    };
    # A public name, so the probe covers AdGuard's upstreams as well as AdGuard.
    dns = {
      prober = "dns";
      timeout = "5s";
      dns = {
        preferred_ip_protocol = "ip4";
        transport_protocol = "udp";
        query_name = "example.com";
        query_type = "A";
        valid_rcodes = [ "NOERROR" ];
      };
    };
  };

  # Blackbox takes the target as a URL parameter and is itself the address
  # scraped; `instance` keeps the target so series read as the URL probed.
  probeJob = module: targets: {
    job_name = "blackbox-${module}";
    metrics_path = "/probe";
    params.module = [ module ];
    # Every 10 s across 30 hosts would be most of Caddy's access log.
    scrape_interval = "1m";
    static_configs = targets;
    relabel_configs = [
      {
        source_labels = [ "__address__" ];
        target_label = "__param_target";
      }
      {
        source_labels = [ "__param_target" ];
        target_label = "instance";
      }
      {
        target_label = "__address__";
        replacement = "127.0.0.1:${toString port}";
      }
    ];
  };
in
{
  services.prometheus.exporters.blackbox = {
    enable = true;
    listenAddress = "127.0.0.1";
    # JSON is YAML. The module runs `blackbox_exporter --config.check` on it at
    # build time.
    configFile = pkgs.writeText "blackbox.yml" (builtins.toJSON { inherit modules; });
  };

  services.prometheus.scrapeConfigs = [
    (probeJob "https" (
      lib.mapAttrsToList (name: s: {
        targets = [ s.url ];
        labels.service = name;
      }) vhosts
    ))
    (probeJob "dns" [
      {
        targets = [ "127.0.0.1:53" ];
        labels.service = "adguard";
      }
    ])
  ];
}
