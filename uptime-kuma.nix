let
  port = 3001;
in
{
  services.uptime-kuma = {
    enable = true;
    # settings is a freeform attrsOf str, so this is a string, not a port.
    settings.PORT = toString port;
  };

  shlam.services.uptime-kuma = {
    subdomain = "uptime";
    inherit port;
    dashboard = {
      title = "Uptime Kuma";
      group = "Productivity & Utilities";
      order = 20;
      icon = "uptime-kuma.svg";
      description = "Service Monitoring";
    };
  };
}
