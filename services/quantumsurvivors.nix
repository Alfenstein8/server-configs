{ pkgs, ... }:
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
      
      ExecStart = "${pkgs.nodejs_25}/bin/node server/app.js -p 8787";
      
      Restart = "on-failure";
      RestartSec = "5s";
    };
    
    # This ensures bun is available in the service environment
    path = [ pkgs.nodejs_25 ];
  };
  networking.firewall.allowedTCPPorts = [8787];
}
