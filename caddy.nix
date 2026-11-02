{
  # Virtual hosts are not defined here any more. Each service declares its own
  # with shlam.services.<name> in its own module (see ./registry.nix), so that
  # commenting a module out of ./configuration.nix also removes its route --
  # which is what the dawarich, netdata and vpn entries deleted here failed to
  # do, leaving three hostnames serving 502s.
  services.caddy.enable = true;

  # Prometheus metrics, scraped off the admin API on localhost:2019 (see
  # prometheus.nix). Since 2.10 Caddy counts HTTP requests only when asked to,
  # and per_host adds the `host` label -- without it every vhost on a listener
  # is one series.
  services.caddy.globalConfig = ''
    metrics {
      per_host
    }
  '';
}
