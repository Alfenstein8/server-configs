# Luanti (formerly Minetest) server running Mineclonia.
# Connect with the Luanti client to the base domain, port 30000 (UDP).
# https://docs.luanti.org/for-server-hosts/setup/
{ pkgs, ... }:
let
  port = 30000;
  dataDir = "/mnt/storage/data/luanti"; # under /mnt/storage/data, so restic backs it up

  # Luanti ships no game and nixpkgs packages none. A game's id is its
  # directory name, so this is the folder Luanti reads `mineclonia` from.
  games = pkgs.linkFarm "luanti-games" {
    mineclonia = pkgs.fetchgit {
      url = "https://codeberg.org/mineclonia/mineclonia.git";
      rev = "refs/tags/0.124.1";
      hash = "sha256-6/idt4I+gmFIjX82Lu/LsxXeP36/yomvFJAU+6urXgY=";
    };
  };
in
{
  services.minetest-server = {
    enable = true;
    inherit port;
    gameId = "mineclonia";
    # Created on first start if missing.
    world = "${dataDir}/world";
    # https://github.com/luanti-org/luanti/blob/master/builtin/settingtypes.txt
    config = {
      server_name = "Shlambert Luanti";
      server_description = "Shlambert Mineclonia";
      motd = "Shlambert Luanti!";
      server_announce = false; # stay off the public server list
      max_users = 5;
      creative_mode = false;
      enable_damage = true;

      # Exposed to the internet, and Luanti has no account authority: anyone
      # can create an account just by connecting. So instead of a whitelist,
      # new accounts can look around and chat but not build or dig. Let a
      # player in from in-game chat:
      #   /grant <name> interact
      # `name` is the admin and gets every privilege. Log in as it right
      # after the first deploy, before anyone else claims the name.
      name = "alfred";
      default_privs = "shout";
      disallow_empty_password = true;
    };
  };

  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 minetest minetest -" ];

  systemd.services.minetest-server = {
    environment.LUANTI_GAME_PATH = "${games}";
    unitConfig.RequiresMountsFor = [ dataDir ];
  };

  networking.firewall.allowedUDPPorts = [ port ];
}
