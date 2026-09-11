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
  # node away from home reaches every service over the tunnel. MagicDNS answers
  # these itself, without consulting a nameserver at all, which is what makes
  # them work whatever resolver the node's network happened to hand it. A name
  # with no record here falls through to that resolver instead -- off-network
  # that means public DNS, the WAN address, and a :443 the router does not
  # forward to this Caddy. immich was the one record written here by hand, and
  # was for exactly that reason the only service that worked over the tailnet.
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
        # These two belong together, and the module asserts it: overriding a
        # client's resolver while handing it no nameserver would leave the node
        # unable to resolve anything at all.
        #
        # MagicDNS forwards every name it does not answer itself to
        # nameservers.global -- including headscale.shlambert.top, which a node
        # has to resolve *before* it has a tunnel to resolve it through. With
        # AdGuard's LAN address there, off-network the control server's own name
        # resolved to nothing and the client logged itself out with
        # `fetch control key: [...] context canceled`, with no way back.
        #
        # So: no nameserver, and no override. The node keeps whatever resolver
        # its network already gave it -- carrier DNS on mobile, AdGuard over
        # DHCP at home, so filtering on the LAN is unaffected. The services do
        # not need one either: extra_records below answers all of them locally,
        # and neither those records nor base_domain are governed by
        # override_local_dns.
        #
        # Getting AdGuard back on the road means making it reachable without a
        # healthy tunnel first -- bind it to the tailnet address, or advertise
        # the LAN subnet route -- and the control server's name has to stay on
        # public DNS either way, or the wedge above comes straight back.
        override_local_dns = false;
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
