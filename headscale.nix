{ config, lib, ... }:
let
  # Router forward: WAN 8444 -> this port. Deliberately the same number on both
  # sides: server_url below carries it, and a node dials that URL verbatim from
  # the LAN too, so a WAN-only port number would leave local clients knocking on
  # a port nothing serves. 443 is not on the table -- it is the shared listener
  # every other vhost lives on, and the WAN 443 forward is zehra.click's.
  publicPort = 8444;

  # The homeserver's own tailnet address, from `headscale nodes list`. Assigned
  # at registration rather than declared, so it is state this repo cannot
  # derive: delete and re-register the node and it may come back different, at
  # which point every record below points at nothing.
  tailnetIP = "100.64.0.2";

  # One A record per vhost, all pointing at the server's tailnet address, so a
  # node away from home resolves every service without having to reach AdGuard
  # first. nameservers.global below is 192.168.0.188 -- a LAN address, which
  # off-network answers nothing until the LAN subnet route is both advertised
  # and approved. MagicDNS serves these records itself, with no route involved,
  # which is why immich (the one record that used to be here by hand) was the
  # only service that worked over the tailnet.
  #
  # Two kinds of host stay out of it:
  #   - headscale itself. A node has to reach the control server *before* it has
  #     a tailnet, so that name must resolve to something reachable without one.
  #   - hosts on another domain (zehra.click). Those are public and resolve on
  #     their own, and a tailnet-only answer would go stale the day one moves
  #     off this box.
  tailnetHosts = lib.filterAttrs (
    name: s:
    name != "headscale"
    && s.vhost
    && lib.hasSuffix ".${config.shlam.domain}" s.host
  ) config.shlam.services;

  extraRecords = lib.mapAttrsToList (_: s: {
    name = s.host;
    type = "A";
    value = tailnetIP;
  }) tailnetHosts;
in
{
  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 3006;
    settings = {
      dns = {
        base_domain = "ts.${config.shlam.domain}";
        # Deliberately empty. This is the resolver MagicDNS forwards every name
        # it does not answer itself to -- including headscale.shlambert.top,
        # which a node must resolve *before* it has a working tunnel. Pointing
        # it at AdGuard's LAN address meant that off-network the control
        # server's own name resolved to nothing, and the client logged itself
        # out with `fetch control key: [...] context canceled`.
        #
        # The services do not need it: extra_records above answers all of them,
        # locally, without a nameserver. And filtering at home is unaffected --
        # DHCP still hands out AdGuard on the LAN. Away from home the device
        # now uses whatever resolver its network gives it, which is the point:
        # it is always reachable.
        #
        # Getting AdGuard back on the road means making it reachable without
        # the tunnel being healthy first (bind it to the tailnet address, or
        # advertise the LAN subnet route) -- and the control server's name has
        # to stay on public DNS either way.
        nameservers.global = [ ];
        extra_records = extraRecords;
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
