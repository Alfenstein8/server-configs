{ config, ... }:
{
  services.mealie = {
    enable = true;
    port = 8001;
  };

  shlam.services.mealie = {
    subdomain = "menu";
    port = config.services.mealie.port;
    dashboard = {
      title = "Mealie";
      group = "Productivity & Utilities";
      order = 40;
      icon = "mealie.svg";
      description = "Recipes & Meal Planning";
    };
  };
}
