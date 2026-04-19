{
  services.radicale = {
    enable = true;
    settings = {
      storage.filesystem_folder = "/mnt/storage/data/radicale";
      server.hosts = [ "localhost:5232" ];
      auth = {
        type = "htpasswd";
        htpasswd_filename = "/etc/nixos/radicale-users";
        htpasswd_encryption = "bcrypt";
      };
    };
  };
}
