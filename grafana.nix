{ config, ... }:
{
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3010;
        enforce_domain = true;
        enable_gzip = true;
        domain = config.shlam.services.grafana.host;
        # Without it Grafana builds its own links -- alert notifications, share
        # links, redirects -- as http://<domain>:3010/, the loopback port
        # rather than the Caddy vhost.
        root_url = config.shlam.services.grafana.url;
      };
      security.secret_key = "$__file{${config.age.secrets.grafana.path}}";
      analytics.reporting_enabled = false;
    };
  };

  services.grafana.provision = {
    enable = true;
    datasources.settings.datasources = [
      {
        name = "Prometheus";
        type = "prometheus";
        # Loopback, not listenAddress: that is a bind address (0.0.0.0 by
        # default), not something to connect to.
        url = "http://127.0.0.1:${toString config.services.prometheus.port}";
        isDefault = true;
      }

      {
        name = "Loki";
        type = "loki";
        url = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
      }
    ];
    alerting = {
      contactPoints.settings.contactPoints = [
        {
          name = "ntfy";
          receivers = [
            {
              uid = "ntfy-receiver";
              type = "webhook";
              settings = {
                url = "https://ntfy.sh/shlambert-metrics-alert-a8888";
                httpMethod = "POST";
              };
            }
          ];
        }
      ];
    };
  };

  shlam.services.grafana = {
    port = config.services.grafana.settings.server.http_port;
    dashboard = {
      title = "Grafana";
      group = "Infrastructure";
      order = 10;
      icon = "grafana.svg";
      description = "Metrics & Dashboards";
    };
  };
}
