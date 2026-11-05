{ lib, config, ... }:
# VPN gateway. prowlarr, qbittorrent and flaresolverr share its network
# namespace (--network=container:gluetun), so their ports are published here
# rather than by the services themselves. Caddy still reaches them on
# localhost.
let
  qbittorrent = toString config.shlam.services.qbittorrent.port;
  prowlarr = toString config.shlam.services.prowlarr.port;
in
{
  virtualisation.oci-containers.containers."gluetun" = {
    image = "qmcgaw/gluetun:pr-3109";
    environment = {
      "VPN_SERVICE_PROVIDER" = "airvpn";
      "VPN_TYPE" = "wireguard";
      "FIREWALL_VPN_INPUT_PORTS" = "52666";
    };
    environmentFiles = [
      "/run/agenix/airvpn"
    ];
    volumes = [
      "/mnt/appdata/gluetun:/gluetun:rw"
    ];
    ports = [
      "${qbittorrent}:${qbittorrent}/tcp"
      "6881:6881/tcp"
      # Loopback only: prowlarr is behind Authelia (see ./prowlarr.nix), and a
      # port published on 0.0.0.0 would be a way around it.
      "127.0.0.1:${prowlarr}:${prowlarr}/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      "--cap-add=NET_ADMIN"
      "--device=/dev/net/tun:/dev/net/tun:rwm"
      "--health-cmd=ping -c 1 www.google.com || exit 1"
      "--health-interval=20s"
      "--health-retries=5"
      "--health-start-period=30s"
      "--health-timeout=10s"
      "--ip=172.39.0.2"
      "--network-alias=gluetun"
      "--network=servarrnetwork"
      # new
      # "--dns=1.1.1.1"
      "--sysctl=net.ipv4.ping_group_range=0 2147483647"
      # "--sysctl=net.ipv4.conf.all.rp_filter=2"
    ];
  };
  systemd.services."podman-gluetun" = {
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
}
