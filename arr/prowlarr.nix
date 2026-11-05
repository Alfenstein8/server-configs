{ lib, ... }:
let
  # Published by the gluetun container, whose network namespace this shares
  # (see ./gluetun.nix).
  port = 9696;
in
{
  virtualisation.oci-containers.containers."prowlarr" = {
    image = "lscr.io/linuxserver/prowlarr:2.7.0.5723-ls166";
    environment = {
      "PGID" = "100";
      "PUID" = "1000";
      "TZ" = "Europe/Copenhagen";
      # Its own login off, Authelia in front instead -- see ./sonarr.nix.
      "PROWLARR__AUTH__METHOD" = "External";
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
    sso.forward = true;
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
