{ config, ... }:
{
  services.mealie = {
    enable = true;
    port = 8001;
  };

  shlam.services.mealie = {
    subdomain = "menu";
    port = config.services.mealie.port;
  };
}
