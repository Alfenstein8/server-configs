{ config, lib, ... }:
let
  # This box's LAN address. AdGuard binds it, and the rewrite below hands it
  # back to LAN clients, so the two must agree.
  lanIP = "192.168.0.188";

  # Hosts on the router's port forward (shlam.services.<name>.publicPort, see
  # ../registry.nix): their public A records point at the WAN address too.
  publicHosts = lib.mapAttrsToList (_: s: s.host) (
    lib.filterAttrs (_: s: s.vhost && s.publicPort != null) config.shlam.services
  );
in
{
  services.adguardhome = {
    enable = true;
    openFirewall = true;
    host = "0.0.0.0";
    port = 3005;
    settings = {
      users = [
        {
          name = "alfred";
          password = "REMOVED-BCRYPT-HASH";
        }
      ];
      dns = {
        bind_hosts = [
          "127.0.0.1"
          lanIP
        ];
        port = 53;
      };

      # Split horizon for the control server, and for every host published
      # through the router's port forward.
      #
      # *.shlambert.top resolves -- publicly, at the registrar -- to this box's
      # LAN address. That is what makes every service work at home, and it is
      # also why nothing on this domain answers from the internet: an off-network
      # client is handed 192.168.0.188 and dials into its own LAN.
      #
      # headscale is the one name that cannot live with that. A node has to
      # reach the control server *before* it has a tailnet to reach it through
      # (see ./headscale.nix, which keeps this host out of extra_records for
      # exactly that reason), so headscale.shlambert.top needs a real public A
      # record at the registrar pointing at the WAN address.
      #
      # That public record would then follow LAN clients home. server_url is
      # dialled verbatim from inside the network too, so a node at home would be
      # sent out to the WAN address and back again, and only a router that
      # hairpins NAT completes that trip -- plenty do not. This rewrite keeps
      # the LAN path on the LAN and leaves the public answer to the clients that
      # actually need it.
      #
      # The public hosts (p7.shlambert.top, zehra.click) have the same problem,
      # and the same answer: their real A records point at the WAN address, so a
      # phone on the Wi-Fi would be sent out and back in. Their :443 vhosts serve
      # the LAN directly.
      #
      # Note this REPLACES the rewrite list wholesale: mutableSettings defaults
      # to true, so a declared value wins over whatever the web UI holds. Any
      # rewrite added by hand there has to be written in here too, or it is
      # dropped on the next restart.
      filtering.rewrites =
        map
          (domain: {
            inherit domain;
            answer = lanIP;
          })
          (
            lib.unique (
              [ config.shlam.services.headscale.host ] ++ publicHosts
            )
          );
    };
  };

  shlam.services.adguard = {
    port = config.services.adguardhome.port;
    dashboard = {
      title = "AdGuard Home";
      group = "Infrastructure";
      order = 40;
      icon = "adguard-home.svg";
      description = "DNS & Ad Blocking";
    };
  };
}
