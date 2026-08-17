{ config, ... }:
let
  port = 3002;
in
{
  services.dawarich = {
    enable = true;
    localDomain = config.shlam.services.dawarich.host;
    webPort = port;
  };

  shlam.services.dawarich = {
    inherit port;
    dashboard = {
      title = "Dawarich";
      group = "Productivity & Utilities";
      order = 60;
      icon = "dawarich.svg";
      description = "Location History";
    };
  };
}
