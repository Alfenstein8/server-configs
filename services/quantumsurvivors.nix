{ pkgs, ... }:
let
  port = 8787;
in
{
  systemd.services.quantumsurvivors = {
    description = "Quantum Survivors";

    # Ensure the network is up before starting
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "alfred";
      WorkingDirectory = "/home/alfred/manual/QuantumSurvivors";

      ExecStart = "${pkgs.nodejs_26}/bin/node server/app.js -p ${toString port}";

      Restart = "on-failure";
      RestartSec = "5s";
    };

    # This ensures bun is available in the service environment
    path = [ pkgs.nodejs_26 ];
  };

  networking.firewall.allowedTCPPorts = [ port ];

  shlam.services.quantumsurvivors = {
    host = "zehra.click";
    acmeHost = "zehra.click";
    inherit port;

    # The router forwards WAN 443 -> 8443 and WAN 80 -> 8880; both listeners
    # serve only the hosts that name them (this one and hyggr.shlambert.top, see
    # hyggr.nix), so nothing else in the registry is exposed by the forward. 8880 rather than the obvious 8080, which is qbittorrent's (see
    # ../arr/default.nix). The only other host reachable from the internet is
    # headscale, on a forward of its own (see ../headscale.nix).
    publicPort = 8443;
    publicHttpPort = 8880;
    dashboard = {
      title = "Quantum Survivors";
      group = "Productivity & Utilities";
      order = 80;
      icon = "mdi-gamepad-variant";
      description = "Game Server";
    };
  };
}
