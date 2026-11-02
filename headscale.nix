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
  # that means public DNS, which for *.shlambert.top is a wildcard pointing at
  # this box's LAN address. Off the LAN that address routes nowhere, so the
  # request does not fail, it hangs. immich was the one record written here by
  # hand, and was for exactly that reason the only service that worked over the
  # tailnet.
  #
  # Two kinds of host stay out of it:
  #   - headscale itself. A node has to reach the control server *before* it has
  #     a tailnet, so that name must resolve to something reachable without one.
  #     The wildcard above is NOT that: it hands out the LAN address, which is
  #     why this host timed out from mobile data while the forward, the
  #     firewall and Caddy were all working. It needs an A record of its own at
  #     the registrar, pointing at the WAN address, to beat the wildcard --
  #     and ./adguardhome.nix rewrites it back to the LAN address for clients
  #     at home, so a node there does not depend on the router hairpinning NAT.
  #   - hosts on another domain (zehra.click). Those are public and resolve on
  #     their own, and a tailnet-only answer would go stale the day one moves
  #     off this box.
  tailnetHosts = lib.filterAttrs (
    name: s: name != "headscale" && s.vhost && lib.hasSuffix ".${config.shlam.domain}" s.host
  ) config.shlam.services;

  extraRecords = lib.mapAttrsToList (_: s: {
    name = s.host;
    type = "A";
    value = tailnetIP;
  }) tailnetHosts;
in
{
  # This box is its own headscale client, and headscale.shlambert.top now has a
  # public A record pointing at the WAN address (it has to -- that is what lets
  # a node off the LAN find the control server at all). Resolving it here would
  # send the local tailscaled out to the router and back in, a trip that only
  # completes if the router hairpins NAT. Ours does not: tailscaled got an empty
  # body from /key and refused to log in with
  # `key hex has the wrong size, got 0 want 64`.
  #
  # So pin the name locally. Loopback rather than the LAN address because Caddy
  # binds :8444 on every interface and this way the control server stays
  # reachable to itself even if the LAN is down. ./adguardhome.nix does the
  # equivalent for LAN clients that resolve through AdGuard; this box does not,
  # which is exactly how it got stranded.
  networking.hosts."127.0.0.1" = [ config.shlam.services.headscale.host ];

  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 3006;
    settings = {
      dns = {
        base_domain = "ts.${config.shlam.domain}";
        # Hand every node a public resolver, and let MagicDNS be the only DNS
        # it uses. These two belong together, and the module asserts it.
        #
        # The empty list this replaces looked free and was not. With no resolver
        # from the control server, tailscaled falls back to whatever the OS
        # already had -- on a systemd-resolved box, 127.0.0.53. But tailscaled
        # has also rewritten /etc/resolv.conf to 100.100.100.100, and resolved
        # reads that file back as its own global upstream (`resolv.conf mode:
        # foreign`). Each side then forwards to the other. The workstation sat
        # in that cycle logging hundreds of `dns udp query: waiting for response
        # or error from [127.0.0.53]: context deadline exceeded` a second, with
        # the rate limiter dropping the rest.
        #
        # Naming a resolver only breaks the cycle if override_local_dns is true
        # as well: headscale puts nameservers.global in tailcfg's Resolvers when
        # it is set, and in FallbackResolvers when it is not -- and a fallback is
        # consulted only when the OS offers nothing, which is never on the box
        # that had the loop.
        #
        # The old objection to that pair was that AdGuard's LAN address was the
        # only candidate, and a node away from home cannot reach it, so
        # headscale.shlambert.top -- the one name that has to resolve before a
        # tunnel exists to resolve it through -- resolved to nothing and the
        # client logged itself out with `fetch control key: [...] context
        # canceled`, with no way back. A public resolver has no such edge: it
        # answers the registrar's A record for that host from anywhere.
        #
        # At home that record is the WAN address, reached by NAT hairpin, which
        # this router does do -- verified 2026-09-12, /health returns 200 over
        # the WAN address from a LAN client, three times out of three. The
        # comment above `networking.hosts` says it does not; that reading came
        # from probing WAN 443, a listener which answers every unmatched SNI
        # with an empty 200 -- and an empty body from /key is exactly what
        # `key hex has the wrong size, got 0 want 64` reports.
        #
        # The trade is deliberate and asked for: tailnet nodes no longer resolve
        # through AdGuard, so tunnelled queries are unfiltered. LAN clients that
        # are not on the tailnet still get AdGuard over DHCP, unaffected.
        override_local_dns = true;
        nameservers.global = [
          "1.1.1.1"
          "9.9.9.9"
        ];
        extra_records = extraRecords;
      };
      server_url = config.shlam.services.headscale.url;
      logtail.enabled = false;
      # Prometheus scrapes this (prometheus.nix). Pinned because the default,
      # 127.0.0.1:9090, is cockpit's port. NOT 9095: that is Loki's gRPC
      # default (loki.nix sets only its address), and headscale exits at
      # startup when it cannot bind -- which took it down on 2026-11-02.
      metrics_listen_addr = "127.0.0.1:9098";
    };
  };
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";

    # These three replace prefs that used to live only in tailscaled's mutable
    # state, which is why `tailscale up` refused to run without being handed
    # every non-default flag back. Declared here they survive a re-register.
    #
    # The split is not cosmetic, it is what each unit can do:
    #
    #   extraSetFlags  -> `tailscale set`, a oneshot that runs on every boot and
    #                     needs no credential, because it only adjusts a node
    #                     that already exists.
    #   extraUpFlags   -> `tailscale up`, which the module only ever runs from
    #                     tailscaled-autoconnect, and that unit exists solely
    #                     when authKeyFile is set. Hence the key: without it
    #                     these flags are silently inert.
    #
    # --login-server has to be on the `up` side; `tailscale set` has no such
    # flag. Everything else belongs on the `set` side, where it is reapplied
    # every boot rather than only at registration.
    #
    # The payoff is that logging out stops being a dead end. autoconnect polls
    # the backend state and re-registers the moment it sees NeedsLogin, which is
    # exactly the hole this box fell into -- stranded off the tailnet from
    # 2026-09-10 20:39 until someone noticed and ran `tailscale up` by hand.
    authKeyFile = config.age.secrets.tailscale-authkey.path;

    #
    # --reset is load-bearing, not tidiness. A logged-out node still keeps its
    # old prefs, so `tailscale up` trips the "requires mentioning all
    # non-default flags" guard even here -- and since the whole point is to
    # DROP the stale --advertise-routes, no list of flags could ever satisfy
    # that guard. --reset says the declared config wins over whatever
    # accumulated in tailscaled's state, which is the only sane reading of a
    # flag list that lives in this file. It is one of the few flags exempt from
    # the guard, so it does not chase its own tail.
    #
    # It clears what extraSetFlags below sets too; that is fine, tailscaled-set
    # is ordered after tailscaled-autoconnect and puts them straight back.
    extraUpFlags = [
      "--reset"
      "--login-server=${config.shlam.services.headscale.url}"
    ];

    # No --advertise-routes: the /32 this box used to announce was a way to
    # reach its own services, and extra_records above already does that by
    # pointing every vhost at the tailnet address. Announcing a route to a
    # single address the tailnet can already reach bought nothing.
    extraSetFlags = [
      "--accept-routes"
      "--advertise-exit-node"
    ];
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
