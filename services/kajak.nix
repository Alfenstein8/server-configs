{ config, pkgs, ... }:
let
  port = 5554;
in
{
  systemd.services.kajak = {
    description = "Kajak Dev Server";

    # Ensure the network is up before starting
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    serviceConfig = {
      Type = "simple";
      User = "alfred";
      WorkingDirectory = "/home/alfred/manual/kajak";

      ExecStart = "${pkgs.pnpm}/bin/pnpm preview --host --port ${toString port}";

      Restart = "on-failure";
      RestartSec = "5s";

      # Optional but good practice
      StandardOutput = "journal";
      StandardError = "journal";
      Environment = [
        "HOME=/home/alfred"
        "PATH=${pkgs.pnpm}/bin:${pkgs.nodejs}/bin:/run/current-system/sw/bin"
        "ORIGIN=${config.shlam.services.kajak.url}"
      ];
    };

    # This ensures bun is available in the service environment
    path = [
      pkgs.pnpm
      pkgs.nodejs
    ];
  };

  # Predates the reverse proxy: with a vhost in front, this hole is no longer
  # needed for browser access, only for hitting the port directly on the LAN.
  networking.firewall.allowedTCPPorts = [ port ];

  shlam.services.kajak = {
    inherit port;
    dashboard = {
      title = "Kajak";
      group = "Productivity & Utilities";
      order = 70;
      icon = "mdi-kayaking";
      description = "Kajak Dev Server";
    };
  };
}
