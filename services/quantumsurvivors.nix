# Parked: not imported from ./default.nix.
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

      ExecStart = "${pkgs.nodejs_25}/bin/node server/app.js -p ${toString port}";

      Restart = "on-failure";
      RestartSec = "5s";
    };

    # This ensures bun is available in the service environment
    path = [ pkgs.nodejs_25 ];
  };

  # Predates the reverse proxy: with a vhost in front, this hole is no longer
  # needed for browser access, only for hitting the port directly on the LAN.
  networking.firewall.allowedTCPPorts = [ port ];

  shlam.services.quantumsurvivors = {
    subdomain = "quantum";
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
