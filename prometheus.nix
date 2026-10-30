{ config, ... }:
{
  services.prometheus = {
    enable = true;
    # Grafana and Caddy reach it over loopback; nothing else needs to.
    listenAddress = "127.0.0.1";
    port = 9003;
    exporters = {
      node = {
        enable = true;
        listenAddress = "127.0.0.1";
        port = 9000;
        # node_systemd_unit_state, for the failed-unit alert in grafana.nix.
        enabledCollectors = [ "systemd" ];
        extraFlags = [
          # The default exclusions, plus podman's per-container healthcheck
          # units: <container id>-<random>.service/.timer, renamed on every
          # container start, so each restart would mint a new set of series.
          # [.] rather than \. -- systemd would read the backslash as an escape.
          "--collector.systemd.unit-exclude=.+[.](automount|device|mount|scope|slice)|[0-9a-f]{64}-[0-9a-f]+[.](service|timer)"
        ];
      };
      # SMART data for the disk alerts in grafana.nix. "ZFS pool not online"
      # only fires once a disk has already dropped out of the mirror; growing
      # sector counts usually show up weeks before that. Finds the disks itself.
      smartctl = {
        enable = true;
        listenAddress = "127.0.0.1";
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
        job_name = "smartctl";
        static_configs = [
          {
            targets = [ "localhost:${toString config.services.prometheus.exporters.smartctl.port}" ];
          }
        ];
      }
      # The monitoring stack itself, so "Scrape target down" also covers log
      # shipping and storage going quiet -- otherwise nothing says when Alloy
      # stops sending or Loki stops answering.
      {
        job_name = "prometheus";
        static_configs = [ { targets = [ "localhost:${toString config.services.prometheus.port}" ]; } ];
      }
      {
        job_name = "loki";
        static_configs = [
          {
            targets = [ "localhost:${toString config.services.loki.configuration.server.http_listen_port}" ];
          }
        ];
      }
      {
        job_name = "alloy";
        static_configs = [ { targets = [ "localhost:${toString config.shlam.services.alloy.port}" ]; } ];
      }
      {
        # /metrics is served ahead of grafana.nix's enforce_domain check, so
        # plain localhost is not redirected.
        job_name = "grafana";
        static_configs = [
          { targets = [ "localhost:${toString config.services.grafana.settings.server.http_port}" ]; }
        ];
      }
      {
        job_name = "immich";
        # Both ports export the same process_* metrics; `worker` tells them
        # apart without decoding port numbers (see dashboards/immich.nix).
        static_configs = [
          {
            targets = [ "localhost:8083" ];
            labels.worker = "api";
          }
          {
            targets = [ "localhost:8084" ];
            labels.worker = "microservices";
          }
        ];
      }
    ];
  };

  shlam.services.prometheus = {
    port = config.services.prometheus.port;
    dashboard = {
      title = "Prometheus";
      group = "Infrastructure";
      order = 20;
      icon = "prometheus.svg";
      description = "Metrics Collection";
      # Target health. Prometheus has no auth, so this needs no secret.
      extra.widget = {
        type = "prometheus";
        url = "http://localhost:${toString config.services.prometheus.port}";
      };
    };
  };
}
