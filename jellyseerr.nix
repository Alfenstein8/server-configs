{ config, ... }:
{
  services.seerr = {
    enable = true;
    port = 5055;
  };

  shlam.services.jellyseerr = {
    port = config.services.seerr.port;
    dashboard = {
      title = "Jellyseerr";
      group = "Media";
      order = 20;
      icon = "jellyseerr.svg";
      description = "Media Requests";
    };
  };
}
