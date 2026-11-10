{ lib, ... }:
let
  port = 3080;
in
{
  virtualisation.oci-containers.containers."watcharr" = {
    image = "ghcr.io/sbondco/watcharr:v4.3.0";
    volumes = [
      "/mnt/appdata/watcharr:/data:rw"
    ];
    # Loopback only, as in ./sonarr.nix: podman's DNAT skips the NixOS firewall,
    # so a plain "3080:3080" was open to the whole LAN, around Caddy.
    ports = [
      "127.0.0.1:${toString port}:${toString port}/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--ip=172.39.0.7"
      "--network-alias=watcharr"
      "--network=servarrnetwork"
    ];
  };
  systemd.services."podman-watcharr" = {
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

  shlam.services.watcharr = {
    subdomain = "watchlist";
    inherit port;
    dashboard = {
      title = "Watcharr";
      group = "Media";
      shared = true;
      order = 30;
      icon = "watcharr-light.webp";
      description = "Watch list";
    };
  };
}
