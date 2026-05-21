{ config, ... }:
{
  services.tandoor-recipes = {
    enable = true;
    address = "127.0.0.1";
    port = 8001;

    extraConfig = {
      ALLOWED_HOSTS = "menu.shlambert.top";
      MEDIA_ROOT = "/mnt/storage/data/tandoor";
      MEDIA_URL = "/media/";
      SECRET_KEY_FILE = config.age.secrets.tandoor.path;
    };
  };

  services.caddy.virtualHosts."https://menu.shlambert.top".extraConfig = ''
    reverse_proxy localhost:8001
  '';
  users.users.caddy.extraGroups = [ "tandoor_recipes" ];
}
