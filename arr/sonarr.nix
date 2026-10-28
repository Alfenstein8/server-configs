{ lib, ... }:
let
  port = 8989;
in
{
  virtualisation.oci-containers.containers."sonarr" = {
    image = "lscr.io/linuxserver/sonarr:4.0.16.2944-ls302";
    environment = {
      "PGID" = "100";
      "PUID" = "1000";
      "TZ" = "Europe/Copenhagen";
    };
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "/mnt/appdata/sonarr:/config:rw"
      "/mnt/storage/data/media:/data:rw"
    ];
    ports = [
      "${toString port}:${toString port}/tcp"
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
