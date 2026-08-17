let
  port = 5232;
in
{
  services.radicale = {
    enable = true;
    settings = {
      storage.filesystem_folder = "/mnt/storage/data/radicale";
      server.hosts = [ "localhost:${toString port}" ];
      auth = {
        type = "htpasswd";
        htpasswd_filename = "/etc/nixos/radicale-users";
        htpasswd_encryption = "bcrypt";
      };
    };
  };

  shlam.services.radicale = {
    inherit port;
    dashboard = {
      title = "Radicale";
      group = "Productivity & Utilities";
      order = 10;
      icon = "radicale.svg";
      description = "Calendar & Contacts";
    };
  };
}
