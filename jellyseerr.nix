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
      shared = true;
      order = 20;
      icon = "jellyseerr.svg";
      description = "Media Requests";
      extra.widget = {
        type = "seerr";
        url = "http://localhost:${toString config.services.seerr.port}";
        key = "{{HOMEPAGE_VAR_JELLYSEERR_KEY}}";
      };
    };
  };
}
