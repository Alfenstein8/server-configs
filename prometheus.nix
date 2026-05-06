{ config, ... }:
{
  services.prometheus = {
    enable = true;
    port = 9003;
    exporters = {
      node = {
        enable = true;
        port = 9000;
      };
    };

    globalConfig.scrape_interval = "10s"; # "1m"
    scrapeConfigs = [
      {
        job_name = "node";
        static_configs = [
          {
            targets = [ "localhost:${toString config.services.prometheus.exporters.node.port}" ];
          }
        ];
      }
      {
        job_name = "immich";
        static_configs = [
          {
            targets = [
              "localhost:8083"
              "localhost:8084"
            ];
          }
        ];
      }
    ];
  };

  services.caddy.virtualHosts."https://prometheus.shlambert.top".extraConfig = ''
    reverse_proxy localhost:9003
  '';
}
