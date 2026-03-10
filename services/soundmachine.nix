{ pkgs, ... }:
{
  systemd.services.soundmachine = {
    description = "Soundmachine Server";
    
    # Ensure the network is up before starting
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "alfred";
      WorkingDirectory = "/home/alfred/manual/soundmachine/server";
      
      ExecStart = "${pkgs.pnpm}/bin/pnpm preview --host --outDir build";
      
      Restart = "on-failure";
      RestartSec = "5s";

      # Optional but good practice
      StandardOutput = "journal";
      StandardError = "journal";
      Environment = [
        "HOME=/home/alfred"
        "PATH=${pkgs.pnpm}/bin:${pkgs.nodejs}/bin:/run/current-system/sw/bin"
      ];
    };
    
    # This ensures bun is available in the service environment
    path = [ pkgs.pnpm pkgs.nodejs ];
  };
}
