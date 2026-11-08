{ config, ... }:
let
  port = 5232;
in
{
  # The htpasswd file: one user:bcrypt-hash per line. Owned by radicale, which
  # reads it itself. Add or change a user with `htpasswd -nB <user>` (from
  # nixpkgs#apacheHttpd) and paste the line in with ageGen.
  age.secrets.radicale-users = {
    file = ./secrets/radicale-users.age;
    owner = "radicale";
  };

  services.radicale = {
    enable = true;
    settings = {
      storage.filesystem_folder = "/mnt/storage/data/radicale";
      server.hosts = [ "localhost:${toString port}" ];
      auth = {
        type = "htpasswd";
        htpasswd_filename = config.age.secrets.radicale-users.path;
        htpasswd_encryption = "bcrypt";
      };
    };
  };

  shlam.services.radicale = {
    inherit port;
    dashboard = {
      title = "Radicale";
      group = "Productivity & Utilities";
      shared = true;
      order = 10;
      icon = "radicale.svg";
      description = "Calendar & Contacts";
    };
  };
}
