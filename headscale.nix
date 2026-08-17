{ config, ... }:
{
  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 3006;
    settings = {
      dns = {
        base_domain = "ts.${config.shlam.domain}";
        nameservers.global = [ "192.168.0.188" ];
        extra_records = [
          {
            name = config.shlam.services.immich.host;
            type = "A";
            value = "100.64.0.2";
          }

        ];
      };
      server_url = config.shlam.services.headscale.url;
      logtail.enabled = false;
    };
  };
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  shlam.services.headscale = {
    port = config.services.headscale.port;
    dashboard = {
      title = "Headscale";
      group = "Infrastructure";
      order = 60;
      icon = "headscale.svg";
      description = "Tailnet Control Server";
    };
  };
}
