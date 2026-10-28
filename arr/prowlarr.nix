{ lib, ... }:
let
  # Published by the gluetun container, whose network namespace this shares
  # (see ./gluetun.nix).
  port = 9696;
in
{
  virtualisation.oci-containers.containers."prowlarr" = {
    image = "lscr.io/linuxserver/prowlarr:2.3.0.5236-ls136";
    environment = {
      "PGID" = "100";
      "PUID" = "1000";
      "TZ" = "Europe/Copenhagen";
    };
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "/mnt/appdata/prowlarr:/config:rw"
    ];
    dependsOn = [
      "gluetun"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network=container:gluetun"
    ];
  };
  systemd.services."podman-prowlarr" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    partOf = [
      "podman-compose-arr-stack-root.target"
    ];
    wantedBy = [
      "podman-compose-arr-stack-root.target"
    ];
  };

  shlam.services.prowlarr = {
    inherit port;
    dashboard = {
      title = "Prowlarr";
      group = "Media administration";
      order = 40;
      icon = "prowlarr.svg";
      description = "Indexer Management";
      extra.widget = {
        type = "prowlarr";
        url = "http://localhost:${toString port}";
        key = "{{HOMEPAGE_VAR_PROWLARR_KEY}}";
      };
    };
  };
}
