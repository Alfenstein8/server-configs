{ lib, ... }:
let
  port = 7878;
in
{
  virtualisation.oci-containers.containers."radarr" = {
    image = "lscr.io/linuxserver/radarr:6.4.4.10685-ls326";
    environment = {
      "PGID" = "100";
      "PUID" = "1000";
      "TZ" = "Europe/Copenhagen";
      # Its own login off, Authelia in front instead -- see ./sonarr.nix.
      "RADARR__AUTH__METHOD" = "External";
    };
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "/mnt/appdata/radarr:/config:rw"
      "/mnt/storage/data/media:/data:rw"
    ];
    # Loopback only, as in ./sonarr.nix: published on 0.0.0.0 it would be a way
    # around Authelia.
    ports = [
      "127.0.0.1:${toString port}:${toString port}/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--ip=172.39.0.4"
      "--network-alias=radarr"
      "--network=servarrnetwork"
    ];
  };
  systemd.services."podman-radarr" = {
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

  shlam.services.radarr = {
    inherit port;
    sso.forward = true;
    dashboard = {
      title = "Radarr";
      group = "Media administration";
      order = 10;
      icon = "radarr.svg";
      description = "Movie Automation";
      extra.widget = {
        type = "radarr";
        url = "http://localhost:${toString port}";
        key = "{{HOMEPAGE_VAR_RADARR_KEY}}";
      };
    };
  };
}
