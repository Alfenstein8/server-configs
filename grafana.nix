{ config, pkgs, ... }:
let
  # The provisioned Prometheus data source's uid, as Grafana generated it when
  # it was first provisioned. Set nowhere else; changing it would orphan every
  # dashboard and rule that points at it.
  prometheus = "PBFA97CFB590B2093";

  # Dashboards are files Grafana watches, one directory for the lot. Anything
  # here is read-only in the UI; changes go through this list.
  dashboards = pkgs.linkFarm "grafana-dashboards" [
    {
      # grafana.com/grafana/dashboards/1860. Picks its data source through a
      # dashboard variable, so the download is provisioned as-is. Bump the
      # revision and hash together.
      name = "node-exporter-full.json";
      path = pkgs.fetchurl {
        url = "https://grafana.com/api/dashboards/1860/revisions/45/download";
        hash = "sha256-GExrdAnzBtp1Ul13cvcZRbEM6iOtFrXXjEaY6g6lGYY=";
      };
    }
    {
      name = "immich.json";
      path = pkgs.writeText "immich.json" (
        builtins.toJSON (import ./dashboards/immich.nix { datasource = prometheus; })
      );
    }
  ];

  # A Grafana-managed rule is a query (A) plus a threshold expression (C) on
  # it -- the same two steps the UI's simple mode builds. noDataState = OK: a
  # metric that is simply absent (no pool degraded, nothing booted) is not an
  # alert.
  promRule =
    r:
    {
      inherit (r) uid title for;
      condition = "C";
      data = [
        {
          refId = "A";
          datasourceUid = prometheus;
          relativeTimeRange = {
            from = 600;
            to = 0;
          };
          model = {
            refId = "A";
            inherit (r) expr;
            instant = true;
          };
        }
        {
          refId = "C";
          datasourceUid = "__expr__";
          model = {
            refId = "C";
            type = "threshold";
            expression = "A";
            conditions = [
              {
                evaluator = {
                  type = r.op;
                  params = [ r.threshold ];
                };
              }
            ];
          };
        }
      ];
      noDataState = "OK";
      execErrState = "Error";
      annotations.summary = r.summary;
    };
in
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
    dashboards.settings.providers = [
      {
        name = "homeserver";
        folder = "Homeserver";
        options.path = dashboards;
      }
    ];

    alerting = {
      # Grafana fills $VARS in provisioning files from its environment, which
      # is how the webhook URL gets in without touching the repo or the store.
      contactPoints.settings = {
        contactPoints = [
          {
            orgId = 1;
            name = "discord";
            receivers = [
              {
                uid = "discord";
                type = "discord";
                settings.url = "$DISCORD_WEBHOOK_URL";
              }
            ];
          }
        ];
        # Dropping a contact point from this file leaves it in Grafana; it has
        # to be deleted by uid.
        deleteContactPoints = [
          {
            orgId = 1;
            uid = "ntfy-receiver";
          }
        ];
      };

      # Replaces the whole notification policy tree, including anything
      # edited in the UI.
      policies.settings.policies = [
        {
          orgId = 1;
          receiver = "discord";
          group_by = [
            "grafana_folder"
            "alertname"
          ];
          repeat_interval = "12h";
        }
      ];

      rules.settings.groups = [
        {
          orgId = 1;
          name = "homeserver";
          folder = "Homeserver";
          interval = "1m";
          rules = map promRule [
            {
              uid = "filesystem-full";
              title = "Filesystem almost full";
              expr = ''100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|overlay|squashfs|nsfs|fuse.*"} / node_filesystem_size_bytes)'';
              op = "gt";
              threshold = 90;
              for = "10m";
              summary = ''{{ .Labels.mountpoint }} is {{ printf "%.0f" .Values.A.Value }}% full'';
            }
            {
              uid = "target-down";
              title = "Scrape target down";
              expr = "up";
              op = "lt";
              threshold = 1;
              for = "5m";
              summary = "Prometheus cannot scrape {{ .Labels.job }} at {{ .Labels.instance }}";
            }
            {
              # Fires once after boot and resolves itself 15 minutes later.
              uid = "rebooted";
              title = "Server rebooted";
              expr = "time() - node_boot_time_seconds";
              op = "lt";
              threshold = 900;
              for = "0s";
              summary = ''Up for {{ printf "%.0f" .Values.A.Value }} seconds'';
            }
            {
              # One series per pool and state; the one at 1 is the current state.
              uid = "zpool-unhealthy";
              title = "ZFS pool not online";
              expr = ''node_zfs_zpool_state{state!="online"}'';
              op = "gt";
              threshold = 0;
              for = "1m";
              summary = "Pool {{ .Labels.zpool }} is {{ .Labels.state }}";
            }
            {
              # From node_exporter's systemd collector (prometheus.nix). A
              # failed oneshot -- a backup, a cert renewal -- stays failed
              # until its next run, so this keeps repeating until it is fixed
              # or `systemctl reset-failed`.
              uid = "unit-failed";
              title = "Systemd unit failed";
              expr = ''node_systemd_unit_state{state="failed"}'';
              op = "gt";
              threshold = 0;
              for = "1m";
              summary = "{{ .Labels.name }} has failed -- journalctl -u {{ .Labels.name }}";
            }
          ];
        }
      ];
    };
  };

  # Holds DISCORD_WEBHOOK_URL=... for the contact point above.
  systemd.services.grafana.serviceConfig.EnvironmentFile = config.age.secrets.grafana-discord.path;

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
