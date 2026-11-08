{ config, pkgs, ... }:
let
  # `vite preview` is not given an explicit --port, so this is its default.
  # caddy.nix was already assuming it.
  port = 4173;
in
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
        "ORIGIN=${config.shlam.services.soundmachine.url}"
      ];
    };

    # This ensures bun is available in the service environment
    path = [
      pkgs.pnpm
      pkgs.nodejs
    ];
  };

  shlam.services.soundmachine = {
    subdomain = "launchpad";
    inherit port;
    dashboard = {
      title = "Launchpad";
      group = "Productivity & Utilities";
      shared = true;
      order = 50;
      icon = "mdi-music-box";
      description = "Soundmachine";
    };
  };
}
