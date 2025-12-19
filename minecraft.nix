# https://minecraft.wiki/w/Server.properties#Java_Edition
{
  services.minecraft-server = {
    enable = true;
    eula = true;
    openFirewall = true; # Opens the port the server is running on (by default 25565 but in this case 43000)
    declarative = true;
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
  };
}
