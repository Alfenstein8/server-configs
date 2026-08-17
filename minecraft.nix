# Parked: not imported from ./configuration.nix. No registry entry -- the server
# speaks the Minecraft protocol on 43000 (and rcon on 25575), not HTTP.
# https://minecraft.wiki/w/Server.properties#Java_Edition
{ pkgs, inputs, ... }:
{
  imports = [ inputs.nix-minecraft.nixosModules.minecraft-servers ];
  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];
  services.minecraft-servers = {
    enable = true;
    eula = true;
    openFirewall = true; # Opens the port the server is running on (by default 25565 but in this case 43000)
    dataDir = "/mnt/storage/data/minecraft";
    servers.test = {
      enable = true;
      package = pkgs.fabricServers.fabric-1_21_11;
      serverProperties = {
        server-port = 43000;
        difficulty = 2;
        gamemode = 0; # survival (0), creative (1), adventure (2), spectator (3)
        online-mode = false;
        max-players = 5;
        spawn-protection = 0;
        motd = "Shlambert Minecraft!";
        allow-cheats = true;
        enable-rcon = true;
        "rcon.password" = "login_NOW!";
        "rcon.port" = 25575;
      };
      symlinks = {
        mods = pkgs.linkFarmFromDrvs "mods" (
          builtins.attrValues {
            Lithium = pkgs.fetchurl {
              url = "https://modrinth.com/mod/lithium/version/mc1.21.11-0.21.1-fabric";
              sha256 = "sha256-u3WJp1c8W8iKckcm54FlJDpMitjDtTeOKvsMlaLAvc4=";
            };
            FerriteCore = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/uXXizFIs/versions/eRLwt73x/ferritecore-8.0.3-fabric.jar";
              sha256 = "sha256-yG6rrNvwY5ibLKgSyOk/VWuP7/HJ38B8rvodkKXHvzU=";
            };
            NoisiumForked = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/hasdd01q/versions/RHzCanhO/noisium-fabric-2.8.1%2Bmc1.21.11.jar";
              sha256 = "sha256-Lt7/sGQtCRwwPdPuTvmXBy9b8NEDRtMHDVgvVBGyZLo=";
            };
          }
        );
      };

    };
  };
}
