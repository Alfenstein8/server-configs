{ pkgs, ... }:
{
  systemd.services.soundmachine = {
    description = "Soundmachine Bun Server";
    
    # Ensure the network is up before starting
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "alfred";
      WorkingDirectory = "/home/alfred/manual/soundmachine/server";
      
      # We explicitly add 'bun' to the service's PATH
      # This replaces the need for 'nix-shell -p bun'
      ExecStart = "${pkgs.bun}/bin/bun -b run dev --host";
      
      Restart = "on-failure";
      RestartSec = "5s";
    };
    
    # This ensures bun is available in the service environment
    path = [ pkgs.bun ];
  };

}
