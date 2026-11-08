{ config, ... }:
let
  port = 3002;
in
{
  services.dawarich = {
    enable = true;
    localDomain = config.shlam.services.dawarich.host;
    webPort = port;
    # Defaults to true, which would start nginx on :80/:443 alongside Caddy.
    # Caddy fronts it via the registry instead; Rails serves public/ itself.
    configureNginx = false;
  };

  shlam.services.dawarich = {
    inherit port;
    dashboard = {
      title = "Dawarich";
      group = "Productivity & Utilities";
      shared = true;
      order = 60;
      icon = "dawarich.svg";
      description = "Location History";
    };
  };
}
