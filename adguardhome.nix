{ config, lib, pkgs, ... }:
let
  # This box's LAN address. AdGuard binds it, and the rewrite below hands it
  # back to LAN clients, so the two must agree.
  lanIP = "192.168.0.188";

  # The web UI.
  port = 3005;

  # Hosts on the router's port forward (shlam.services.<name>.publicPort, see
  # ../registry.nix): their public A records point at the WAN address too.
  publicHosts = lib.mapAttrsToList (_: s: s.host) (
    lib.filterAttrs (_: s: s.vhost && s.publicPort != null) config.shlam.services
  );
in
{
  # The web UI login's bcrypt hash, alone in the file (`htpasswd -nbB alfred
  # <password> | cut -d: -f2`, from nixpkgs#apacheHttpd). Kept out of
  # settings.users so it stays out of the repository, and written into
  # AdGuardHome.yaml after the module's own preStart has installed or merged
  # it. Read by systemd as root and handed over with LoadCredential, since
  # AdGuard runs as a DynamicUser. If you change the password, change the
  # widget's plaintext in homepage.age (HOMEPAGE_VAR_ADGUARD_PASS) too.
  age.secrets.adguardhome-password.file = ./secrets/adguardhome-password.age;
  systemd.services.adguardhome = {
    serviceConfig.LoadCredential = [
      "password-hash:${config.age.secrets.adguardhome-password.path}"
    ];
    preStart = lib.mkAfter ''
      HASH="$(< "$CREDENTIALS_DIRECTORY/password-hash")" \
        ${lib.getExe pkgs.yq-go} -i \
        '.users = [{"name": "alfred", "password": strenv(HASH)}]' \
        "$STATE_DIRECTORY/AdGuardHome.yaml"
      chmod 600 "$STATE_DIRECTORY/AdGuardHome.yaml"
    '';
  };

  services.adguardhome = {
    enable = true;
    openFirewall = true;
    settings = {
      http.address = "0.0.0.0:${toString port}";
      dns = {
        bind_hosts = [
          "127.0.0.1"
          lanIP
        ];
        port = 53;
      };

      # Security lists only: malware, phishing and scams, no ad blocking.
      # Like the rewrites below, this replaces the UI's list on every start.
      # Kept small on purpose -- overlapping lists add little but make it
      # harder to tell which one broke a site (the query log names the list).
      # The ids are the ones in AdGuard's catalog
      # (adguardteam.github.io/HostlistsRegistry/assets/filters.json).
      #
      # Not Dandelion Sprout's Anti-Malware List (catalog 12): it blocks all of
      # *.top bar a short denyallow, and that takes *.shlambert.top with it.
      # Check any list added here for TLD-wide rules (||*.top^ and the like).
      filters =
        map
          (f: f // { enabled = true; })
          [
            {
              # Malware, phishing, C2, cryptojacking. Already includes
              # URLhaus, PhishTank and OpenPhish, so those are not listed.
              id = 44;
              name = "HaGeZi's Threat Intelligence Feeds";
              url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_44.txt";
            }
            {
              # Fake shops, subscription traps, scam sites. Not in the
              # catalog, so straight from HaGeZi; the id is just unused there.
              id = 1001;
              name = "HaGeZi's Fake";
              url = "https://cdn.jsdelivr.net/gh/hagezi/dns-blocklists@latest/adblock/fake.txt";
            }
            {
              id = 10;
              name = "Scam Blocklist by DurableNapkin";
              url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_10.txt";
            }
            {
              id = 50;
              name = "uBlock filters - Badware risks";
              url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_50.txt";
            }
          ];

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
      # The public hosts (hyggr.shlambert.top, zehra.click) have the same problem,
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
    inherit port;
    dashboard = {
      title = "AdGuard Home";
      group = "Infrastructure";
      order = 40;
      icon = "adguard-home.svg";
      description = "DNS & Ad Blocking";
      # The plaintext of the bcrypt hash in adguardhome-password.age (see top).
      extra.widget = {
        type = "adguard";
        url = "http://localhost:${toString port}";
        username = "alfred";
        password = "{{HOMEPAGE_VAR_ADGUARD_PASS}}";
      };
    };
  };
}
