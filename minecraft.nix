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
      # 26.x needs Java 25, but nix-minecraft's Fabric servers run the system
      # default jre_headless (21) instead of the version Mojang asks for.
      package = pkgs.fabricServers.fabric-26_2.override { jre_headless = pkgs.jdk25_headless; };
      serverProperties = {
        server-port = 43000;
        difficulty = 2;
        gamemode = 0; # survival (0), creative (1), adventure (2), spectator (3)
        # Exposed to the internet: players must own a real Minecraft account
        # and be on the whitelist. Add them from the console:
        #   sudo -u minecraft tmux -S /run/minecraft/test.sock attach
        #   whitelist add <username>
        # Detach with Ctrl+b then d: Ctrl+c stops the server. Attach as
        # minecraft, not root, since a root-owned socket left behind blocks
        # the service from restarting.
        online-mode = true;
        white-list = true;
        enforce-whitelist = true; # kicks online players removed from the list
        max-players = 5;
        spawn-protection = 0;
        motd = "Shlambert Minecraft!";
        allow-cheats = true;
        # No RCON: openFirewall would expose its port too. Use the tmux console.
        enable-rcon = false;
      };
      symlinks = {
        mods = pkgs.linkFarmFromDrvs "mods" (
          builtins.attrValues {
            Lithium = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/f7vZ0VWU/lithium-fabric-0.25.3%2Bmc26.2.jar";
              sha512 = "148b638f3c6229fbaf487120a2344a0af5e411a5aa6533d5db9d75da0a8c0d8304f63eb4cca13f4d03b2c9b4c23d559dd74c1d832422ef8a3087bd005e62a8bd";
            };
            FerriteCore = pkgs.fetchurl {
              url = "https://cdn.modrinth.com/data/uXXizFIs/versions/d5ddUdiB/ferritecore-9.0.0-fabric.jar";
              sha512 = "d81fa97e11784c19d42f89c2f433831d007603dd7193cee45fa177e4a6a9c52b384b198586e04a0f7f63cd996fed713322578bde9a8db57e1188854ae5cbe584";
            };
            # Noisium has no 26.2 build yet.
          }
        );
      };

    };
  };
}
