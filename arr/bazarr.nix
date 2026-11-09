{ lib, ... }:
let
  port = 6767;
in
{
  virtualisation.oci-containers.containers."bazarr" = {
    image = "lscr.io/linuxserver/bazarr:v1.6.2-ls371";
    environment = {
      "PGID" = "100";
      "PUID" = "1000";
      "TZ" = "Europe/Copenhagen";
    };
    volumes = [
      "/etc/localtime:/etc/localtime:ro"
      "/mnt/appdata/bazarr:/config:rw"
      "/mnt/storage/data/media:/data:rw"
    ];
    # Loopback only, as in ./sonarr.nix: published on 0.0.0.0 it would be a way
    # around Authelia.
    ports = [
      "127.0.0.1:${toString port}:${toString port}/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--ip=172.39.0.6"
      "--network-alias=bazarr"
      "--network=servarrnetwork"
    ];
  };
  systemd.services."podman-bazarr" = {
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

  shlam.services.bazarr = {
    inherit port;
    # Bazarr has no "External" mode and no environment override for its login;
    # it is switched off by hand: Settings -> General -> Security, clear the
    # Authentication field with its x (there is no "None" entry), Save. The
    # setting lives in /mnt/appdata/bazarr's config.yaml.
    sso.forward = true;
    dashboard = {
      title = "Bazarr";
      group = "Media administration";
      order = 30;
      icon = "bazarr.svg";
      description = "Subtitle Automation";
      extra.widget = {
        type = "bazarr";
        url = "http://localhost:${toString port}";
        key = "{{HOMEPAGE_VAR_BAZARR_KEY}}";
      };
    };
  };
}
