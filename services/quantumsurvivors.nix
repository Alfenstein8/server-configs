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
    dashboard = {
      title = "Quantum Survivors";
      group = "Productivity & Utilities";
      order = 80;
      icon = "mdi-gamepad-variant";
      description = "Game Server";
    };
  };
}
