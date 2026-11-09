{
  config,
  lib,
  pkgs,
  ...
}:
{
  services.cockpit = {
    enable = true;
    port = 9090;
    allowed-origins = [ config.shlam.services.cockpit.url ];
  };

  # Loopback only. The module listens on every interface; the firewall keeps
  # 9090 shut, but behind Authelia the vhost should be the only door, not one
  # that relies on the firewall to stay the only one. The leading "" clears
  # the module's list rather than adding to it.
  systemd.sockets.cockpit.listenStreams = lib.mkForce [
    ""
    "127.0.0.1:${toString config.services.cockpit.port}"
  ];

  environment.systemPackages = with pkgs; [ cockpit ];

  shlam.services.cockpit = {
    port = config.services.cockpit.port;
    # On top of Cockpit's own PAM login, which stays: it is what decides which
    # system user the session runs as.
    sso.forward = true;
    dashboard = {
      title = "Cockpit";
      group = "Infrastructure";
      order = 50;
      icon = "cockpit.svg";
      description = "Server Administration";
    };
  };
}
