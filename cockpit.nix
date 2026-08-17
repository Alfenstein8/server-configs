{ config, pkgs, ... }:
{
  services.cockpit = {
    enable = true;
    port = 9090;
    allowed-origins = [ config.shlam.services.cockpit.url ];
  };

  environment.systemPackages = with pkgs; [ cockpit ];

  shlam.services.cockpit = {
    port = config.services.cockpit.port;
    dashboard = {
      title = "Cockpit";
      group = "Infrastructure";
      order = 50;
      icon = "cockpit.svg";
      description = "Server Administration";
    };
  };
}
