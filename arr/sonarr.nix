{ lib, ... }:
let
  port = 8989;
in
{
  virtualisation.oci-containers.containers."sonarr" = {
    image = "lscr.io/linuxserver/sonarr:4.0.20.3014-ls329";
    environment = {
      "PGID" = "100";
      "PUID" = "1000";
      "TZ" = "Europe/Copenhagen";
      # Sonarr's own login off: Authelia stands in front of it (sso.forward
      # below). The API still wants its key either way. Overrides config.xml's
      # AuthenticationMethod, which is otherwise only settable in the UI.
      "SONARR__AUTH__METHOD" = "External";
    };
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "/mnt/appdata/sonarr:/config:rw"
      "/mnt/storage/data/media:/data:rw"
    ];
    # Loopback only. Podman's port forwarding is DNAT ahead of the NixOS
    # firewall, so a plain "8989:8989" was open to the whole LAN -- which, with
    # Sonarr's login off, would walk straight around Authelia. Caddy, homepage
    # and private-tags use localhost; prowlarr and bazarr use the container
    # network (sonarr:8989).
    ports = [
      "127.0.0.1:${toString port}:${toString port}/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--ip=172.39.0.3"
      "--network-alias=sonarr"
      "--network=servarrnetwork"
    ];
  };
  systemd.services."podman-sonarr" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-servarrnetwork.service"
    ];
    requires = [
      "podman-network-servarrnetwork.service"
    ];
    partOf = [
      "podman-compose-arr-stack-root.target"
    ];
    wantedBy = [
      "podman-compose-arr-stack-root.target"
    ];
  };

  shlam.services.sonarr = {
    inherit port;
    sso.forward = true;
    dashboard = {
      title = "Sonarr";
      group = "Media administration";
      order = 20;
      icon = "sonarr.svg";
      description = "TV Show Automation";
      extra.widget = {
        type = "sonarr";
        url = "http://localhost:${toString port}";
        key = "{{HOMEPAGE_VAR_SONARR_KEY}}";
      };
    };
  };
}
