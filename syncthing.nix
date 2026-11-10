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

  shlam.services.syncthing = {
    inherit port;
    # The GUI only. Devices sync with each other on 22000 and discover each
    # other on 21027 (openDefaultPorts), never through Caddy, so this doesn't
    # touch them. A tool driving the REST API through this URL would need to
    # use the GUI port directly instead.
    sso.forward = true;
    dashboard = {
      title = "Syncthing";
      group = "File Management";
      order = 30;
      icon = "syncthing.svg";
      description = "File Synchronization";
    };
  };
}
