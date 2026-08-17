let
  port = 8384;
in
{
  services.syncthing = {
    enable = true;
    dataDir = "/mnt/storage/data/syncthing";
    openDefaultPorts = true;
    # The GUI port has no option of its own -- it only exists inside
    # guiAddress, so it is declared here and interpolated in.
    guiAddress = "0.0.0.0:${toString port}";
  };

  shlam.services.syncthing.port = port;
}
