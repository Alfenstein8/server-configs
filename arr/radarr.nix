{ lib, ... }:
let
  port = 7878;
in
{
  virtualisation.oci-containers.containers."radarr" = {
    image = "lscr.io/linuxserver/radarr:6.0.4.10291-ls289";
    environment = {
      "PGID" = "100";
      "PUID" = "1000";
      "TZ" = "Europe/Copenhagen";
    };
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "/mnt/appdata/radarr:/config:rw"
      "/mnt/storage/data/media:/data:rw"
    ];
    ports = [
      "${toString port}:${toString port}/tcp"
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
