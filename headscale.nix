{ config, ... }:
let
  # Router forward: WAN 8444 -> this port. Deliberately the same number on both
  # sides: server_url below carries it, and a node dials that URL verbatim from
  # the LAN too, so a WAN-only port number would leave local clients knocking on
  # a port nothing serves. 443 is not on the table -- it is the shared listener
  # every other vhost lives on, and the WAN 443 forward is zehra.click's.
  publicPort = 8444;
in
{
  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 3006;
    settings = {
      dns = {
        base_domain = "ts.${config.shlam.domain}";
        nameservers.global = [ "192.168.0.188" ];
        extra_records = [
          {
            name = config.shlam.services.immich.host;
            type = "A";
            value = "100.64.0.2";
          }

        ];
      };
      server_url = config.shlam.services.headscale.url;
      logtail.enabled = false;
    };
  };
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  shlam.services.headscale = {
    port = config.services.headscale.port;
    inherit publicPort;

    # Overrides the registry default of https://<host>, because a node bakes
    # server_url in when it registers and has to re-register if it ever changes.
    # The port therefore has to be in there from the very first node onwards --
    # which is also why the :443 vhost the registry still generates is only good
    # for a browser, never as a login server.
    url = "https://${config.shlam.services.headscale.host}:${toString publicPort}";

    dashboard = {
      title = "Headscale";
      group = "Infrastructure";
      order = 60;
      icon = "headscale.svg";
      description = "Tailnet Control Server";
    };
  };
}
