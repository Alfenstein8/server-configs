{ config, lib, ... }:
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
    # After login Authelia sends the browser back here with its own address as
    # Referer, and qBittorrent's CSRF check answers any Referer from another
    # host with a bare 401 "Unauthorized". Drop just that one; a forged
    # cross-site POST still carries an Origin, which qBittorrent checks too.
    # request_header runs after forward_auth in Caddy's order, so Authelia
    # still sees the request untouched.
    extraConfig = ''
      @fromAuth header Referer ${config.shlam.services.auth.url}/*
      request_header @fromAuth -Referer
    '';
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
