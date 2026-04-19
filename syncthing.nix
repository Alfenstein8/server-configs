{
  services.syncthing = {
    enable = true;
    dataDir = "/mnt/storage/data/syncthing";
    openDefaultPorts = true;
    guiAddress = "0.0.0.0:8384";
  };
}
