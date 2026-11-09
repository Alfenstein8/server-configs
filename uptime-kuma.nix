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
    # The module binds 127.0.0.1, so the vhost is the only way in. This also
    # covers the push URLs (/api/push/...) and status pages; nothing uses
    # either today.
    sso.forward = true;
    dashboard = {
      title = "Uptime Kuma";
      group = "Productivity & Utilities";
      order = 20;
      icon = "uptime-kuma.svg";
      description = "Service Monitoring";
    };
  };
}
