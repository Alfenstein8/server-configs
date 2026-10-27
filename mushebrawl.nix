# MusheBrawl signaling server (matchbox_server): introduces players to each
# other over a WebSocket; the matches themselves run peer-to-peer, so this
# carries almost no traffic. The game's default server is
# wss://brawl.shlambert.top, so the host must stay reachable at that name.
#
# nixpkgs ships matchbox-server 0.11; the game is built against 0.14, so it's
# built from crates.io here. To bump it, change the version and swap both
# hashes for lib.fakeHash; the build failures print the new ones.
{ pkgs, ... }:
let
  port = 3536;

  matchbox-server = pkgs.rustPlatform.buildRustPackage rec {
    pname = "matchbox_server";
    version = "0.14.0";
    src = pkgs.fetchCrate {
      inherit pname version;
      hash = "sha256-FF4XxBoxIbYFU7G2E3tuMVyjC70/uWrlWDFUgHMgnDk=";
    };
    cargoHash = "sha256-sIPPwOKniKuvTiYFUC7wnMPLRP4CbPSuUY850DdaXL8=";
  };
in
{
  systemd.services.mushebrawl = {
    description = "MusheBrawl signaling server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    environment.RUST_LOG = "info";

    serviceConfig = {
      # Loopback only; Caddy is the way in (and terminates TLS for wss://).
      ExecStart = "${matchbox-server}/bin/matchbox_server 127.0.0.1:${toString port}";
      Restart = "on-failure";
      RestartSec = "5s";

      # Stateless and open to the internet: give it nothing.
      DynamicUser = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
    };
  };

  shlam.services.mushebrawl = {
    subdomain = "brawl";
    inherit port;

    # Players connect from anywhere, so it joins zehra.click, hyggr and the
    # wishlist on the router's WAN 443 -> 8443 / WAN 80 -> 8880 forward (see
    # services/quantumsurvivors.nix).
    publicPort = 8443;
    publicHttpPort = 8880;
    dashboard = {
      title = "MusheBrawl";
      group = "Productivity & Utilities";
      order = 85;
      icon = "mdi-sword-cross";
      description = "Game signaling server";
    };
  };
}
