{ lib, ... }:
let
  # Published by the gluetun container, whose network namespace this shares
  # (see ./gluetun.nix).
  port = 8080;
in
{
  virtualisation.oci-containers.containers."qbittorrent" = {
    image = "lscr.io/linuxserver/qbittorrent:5.1.4-r3-ls453";
    environment = {
      "PGID" = "100";
      "PUID" = "1000";
      "TZ" = "Europe/Copenhagen";
      "WEBUI_PORT" = toString port;
    };
    volumes = [
      "/mnt/appdata/qbittorrent:/config:rw"
      "/mnt/storage/data/media:/data:rw"
    ];
    dependsOn = [
      "gluetun"
    ];
    log-driver = "journald";
    extraOptions = [
      "--network=container:gluetun"
    ];
  };
  systemd.services."podman-qbittorrent" = {
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

  shlam.services.qbittorrent = {
    subdomain = "torrent";
    inherit port;
    # On top of qBittorrent's own login, which stays: qbit-manage, the
    # private-tags script and the widget below all sign in with it.
    sso.forward = true;
    dashboard = {
      title = "qBittorrent";
      group = "Media administration";
      order = 50;
      icon = "qbittorrent.svg";
      description = "Torrent Client";
      # qBittorrent sees homepage arrive from the podman gateway rather than
      # loopback, so its localhost auth bypass does not apply.
      extra.widget = {
        type = "qbittorrent";
        url = "http://localhost:${toString port}";
        username = "{{HOMEPAGE_VAR_QBIT_USER}}";
        password = "{{HOMEPAGE_VAR_QBIT_PASS}}";
      };
    };
  };
}
