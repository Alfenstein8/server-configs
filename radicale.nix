{
  services.radicale = {
    enable = true;
    settings = {
      storage.filesystem_folder = "/mnt/storage/radicale";
      server.hosts = ["localhost:5232"];
      auth.type = "none";
    };
  };
}
