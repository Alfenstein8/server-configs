{ config, ... }:
{
  # Resource use per cgroup: every podman container (named, through podman's
  # API socket) and every systemd service (by cgroup path). node_exporter only
  # sees the host as a whole.
  services.cadvisor = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9080; # not the default 8080, which is qbittorrent's
    extraOptions = [
      # What the dashboard uses, instead of the default everything-but.
      "-enable_metrics=cpu,memory,network,diskIO,oom_event,pressure"
      # Every image label as a metric label is a lot of series for nothing.
      "-store_container_labels=false"
      # The default is every second.
      "-housekeeping_interval=10s"
    ];
  };
  # The podman API is socket-activated; make sure the socket is there before
  # cAdvisor looks for it, or containers show up as bare cgroup ids.
  systemd.services.cadvisor = {
    wants = [ "podman.socket" ];
    after = [ "podman.socket" ];
  };

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
      # The one Postgres that immich and dawarich share. Connects over the
      # socket as the postgres superuser (peer auth), so there is no password
      # to keep -- it only ever reads the statistics views.
      postgres = {
        enable = true;
        listenAddress = "127.0.0.1";
        runAsLocalSuperUser = true;
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
        job_name = "cadvisor";
        static_configs = [ { targets = [ "localhost:${toString config.services.cadvisor.port}" ]; } ];
      }
      {
        job_name = "postgres";
        static_configs = [
          {
            targets = [ "localhost:${toString config.services.prometheus.exporters.postgres.port}" ];
          }
        ];
      }
      {
        # The admin API, which also serves /metrics (globalConfig in caddy.nix).
        # Loopback-only by default, and that is Caddy's choice, not ours.
        job_name = "caddy";
        static_configs = [ { targets = [ "localhost:2019" ]; } ];
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
