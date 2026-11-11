{ config, pkgs, ... }:
let
  # The provisioned Prometheus data source's uid, as Grafana generated it when
  # it was first provisioned. Set nowhere else; changing it would orphan every
  # dashboard and rule that points at it.
  prometheus = "PBFA97CFB590B2093";
  loki = "P8E80F9AEF21F6940"; # likewise, for Loki

  # Dashboards are files Grafana watches, one directory for the lot. Anything
  # here is read-only in the UI; changes go through this list.
  dashboards = pkgs.linkFarm "grafana-dashboards" (
    [
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
        name = "homeserver.json";
        path = pkgs.writeText "homeserver.json" (
          builtins.toJSON (import ./dashboards/homeserver.nix { inherit prometheus loki; })
        );
      }
      {
        name = "immich.json";
        path = pkgs.writeText "immich.json" (
          builtins.toJSON (import ./dashboards/immich.nix { datasource = prometheus; })
        );
      }
    ]
    # The rest share dashboards/lib.nix and take just the Prometheus uid.
    ++
      map
        (name: {
          name = "${name}.json";
          path = pkgs.writeText "${name}.json" (
            builtins.toJSON (import ./dashboards/${name}.nix { datasource = prometheus; })
          );
        })
        [
          "caddy"
          "postgres"
          "endpoints"
          "containers"
          "apps"
          "home-assistant"
        ]
  );

  # A Grafana-managed rule is a query (A) plus a threshold expression (C) on
  # it -- the same two steps the UI's simple mode builds. noDataState = OK: a
  # metric that is simply absent (no pool degraded, nothing booted) is not an
  # alert.
  rule = datasourceUid: instantQuery: r: {
    inherit (r) uid title for;
    condition = "C";
    data = [
      {
        refId = "A";
        inherit datasourceUid;
        relativeTimeRange = {
          from = 600;
          to = 0;
        };
        model = {
          refId = "A";
          inherit (r) expr;
        }
        // instantQuery;
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
  promRule = rule prometheus { instant = true; };
  # The same shape over a LogQL metric query, for what only the journal says.
  lokiRule = rule loki { queryType = "instant"; };
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

      # "Sign in with Authelia" (authelia.nix holds the other half of this
      # client). The local login form stays, for the admin account and for when
      # Authelia is down. Members of the Authelia group `admins` get Admin;
      # everyone else who can log in at all gets Viewer.
      "auth.generic_oauth" =
        let
          issuer = config.shlam.services.auth.url;
        in
        {
          enabled = true;
          name = "Authelia";
          icon = "signin";
          client_id = "grafana";
          client_secret = "$__file{${config.age.secrets.grafana-oidc.path}}";
          scopes = "openid profile email groups";
          empty_scopes = false;
          use_pkce = true;
          auth_url = "${issuer}/api/oidc/authorization";
          token_url = "${issuer}/api/oidc/token";
          api_url = "${issuer}/api/oidc/userinfo";
          login_attribute_path = "preferred_username";
          name_attribute_path = "name";
          groups_attribute_path = "groups";
          # Authelia already refuses non-admins (authorization_policy in
          # authelia.nix). Strict mode is the second lock: no `admins` group,
          # no role, and Grafana refuses the login instead of making a Viewer.
          role_attribute_path = "contains(groups[*], 'admins') && 'Admin'";
          role_attribute_strict = true;
          allow_sign_up = true;
        };
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
      # is how the ntfy token gets in without touching the repo or the store.
      contactPoints.settings = {
        contactPoints = [
          {
            orgId = 1;
            name = "ntfy";
            receivers = [
              {
                # Not "ntfy-receiver": that uid is the old ntfy.sh one, deleted
                # below on every start.
                uid = "ntfy";
                type = "webhook";
                settings = {
                  # Loopback rather than the public URL, so an alert still
                  # gets out while Caddy or DNS is what's broken. ntfy's
                  # built-in grafana template turns the webhook's JSON into a
                  # title and message.
                  url = "http://${config.services.ntfy-sh.settings.listen-http}/homeserver?template=grafana";
                  httpMethod = "POST";
                  authorization_scheme = "Bearer";
                  authorization_credentials = "$NTFY_TOKEN";
                };
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
          receiver = "ntfy";
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
          rules =
            map promRule [
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
              {
                # Written by backup.nix after each successful run. Both jobs are
                # daily, so 36 hours is one missed night plus slack. A job that
                # has not succeeded since this was added has no series yet.
                uid = "backup-overdue";
                title = "Backup overdue";
                expr = "(time() - backup_last_success_timestamp_seconds) / 3600";
                op = "gt";
                threshold = 36;
                for = "0s";
                summary = ''{{ .Labels.unit }} last succeeded {{ printf "%.0f" .Values.A.Value }} hours ago'';
              }
              # The disk rules below are from the smartctl exporter (prometheus.nix).
              {
                uid = "smart-failed";
                title = "Disk SMART health failed";
                expr = "smartctl_device_smart_status";
                op = "lt";
                threshold = 1;
                for = "0s";
                summary = "{{ .Labels.device }} fails its own SMART health check -- replace it";
              }
              {
                # Raw counts. Any at all on these disks is the early sign of one
                # wearing out; check `smartctl -a` and plan the swap.
                uid = "smart-bad-sectors";
                title = "Disk has bad sectors";
                expr = ''smartctl_device_attribute{attribute_value_type="raw", attribute_name=~"Reallocated_Sector_Ct|Current_Pending_Sector|Offline_Uncorrectable"}'';
                op = "gt";
                threshold = 0;
                for = "0s";
                summary = ''{{ .Labels.device }}: {{ .Labels.attribute_name }} = {{ printf "%.0f" .Values.A.Value }}'';
              }
              {
                uid = "nvme-warning";
                title = "NVMe health warning";
                expr = "smartctl_device_critical_warning + smartctl_device_media_errors";
                op = "gt";
                threshold = 0;
                for = "0s";
                summary = "{{ .Labels.device }} reports a critical warning or media errors -- smartctl -a /dev/{{ .Labels.device }}";
              }
              {
                # Spinning disks only; the NVMe runs hotter and is fine with it.
                uid = "hdd-hot";
                title = "Hard disk too hot";
                expr = ''smartctl_device_temperature{temperature_type="current"} and on (device) smartctl_device_rotation_rate > 0'';
                op = "gt";
                threshold = 45;
                for = "30m";
                summary = ''{{ .Labels.device }} is at {{ printf "%.0f" .Values.A.Value }} °C'';
              }
              {
                # The exporter answers even when Postgres does not, so "Scrape
                # target down" stays quiet; pg_up is its own verdict.
                uid = "postgres-down";
                title = "PostgreSQL down";
                expr = "pg_up";
                op = "lt";
                threshold = 1;
                for = "2m";
                summary = "postgres_exporter cannot reach PostgreSQL -- journalctl -u postgresql";
              }
              {
                # The kernel's own count, so it covers native services and
                # containers alike; the Containers & services dashboard shows
                # who was using the memory.
                uid = "oom-kill";
                title = "Out-of-memory kill";
                expr = "increase(node_vmstat_oom_kill[10m])";
                op = "gt";
                threshold = 0;
                for = "0s";
                summary = ''The kernel killed {{ printf "%.0f" .Values.A.Value }} process(es) for memory in the last 10 minutes -- journalctl -k | grep -i oom'';
              }
              # The two below are from the blackbox probes (blackbox.nix).
              {
                # Caddy's 502 when a backend is gone, a TLS failure, or DNS
                # not answering. One alert per service.
                uid = "endpoint-down";
                title = "Endpoint not answering";
                expr = "max by (service, instance) (probe_success)";
                op = "lt";
                threshold = 1;
                for = "5m";
                summary = "{{ .Labels.service }} ({{ .Labels.instance }}) fails its probe -- see the Endpoints dashboard";
              }
              {
                # ACME renews 30 days ahead, so under 21 means renewal has
                # been failing for over a week. One series per URL would be
                # thirty alerts for one wildcard; the soonest is enough.
                #
                # No label_replace to pull out the domain: written "$$1" (on the
                # theory that Grafana expands $VARS here) it reached Prometheus
                # unchanged and labelled the alert "$1" literally. Avoiding `$`
                # beats guessing Grafana's rules. The Endpoints dashboard has
                # the per-domain view.
                uid = "cert-expiring";
                title = "Certificate not renewing";
                expr = "min((probe_ssl_earliest_cert_expiry - time()) / 86400)";
                op = "lt";
                threshold = 21;
                for = "1h";
                summary = ''A served certificate expires in {{ printf "%.0f" .Values.A.Value }} days -- systemctl status 'acme-order-renew-*' '';
              }
              {
                # The Energi Fyn integration (home-assistant/) logs one line
                # and goes quiet when its refresh token is rejected; the price
                # sensors turn unavailable and the plug scheduler silently
                # stops. It has no reauth flow, so the fix is deleting and
                # re-adding the integration. Home Assistant itself being down
                # is "Scrape target down"'s job.
                uid = "electricity-prices-unavailable";
                title = "Electricity prices unavailable";
                expr = ''homeassistant_entity_available{entity=~"sensor.*_current_price"}'';
                op = "lt";
                threshold = 1;
                for = "1h";
                summary = "{{ .Labels.entity }} is unavailable -- the cheap-hours plug is not scheduling. Check the Energi Fyn integration in Home Assistant";
              }
            ]
            ++ map lokiRule [
              {
                # Checksum and I/O errors on a pool that stays ONLINE, which
                # "ZFS pool not online" never sees -- a scrub that repairs
                # something, a disk that fails a read. Only ZED reports them,
                # one journal line per event. Matched on the syslog identifier:
                # those lines often reach the journal without a unit. `delay`
                # (slow I/O) is left out; HDDs trip it under load.
                uid = "zfs-errors";
                title = "ZFS reported errors";
                expr = ''sum(count_over_time({job="systemd-journal", identifier="zed"} |~ "class=(checksum|io|data|deadman|probe_failure|authentication) " [1h]))'';
                op = "gt";
                threshold = 0;
                for = "0s";
                summary = ''ZED logged {{ printf "%.0f" .Values.A.Value }} error events in the last hour -- zpool status -v'';
              }
            ];
        }
      ];
    };
  };

  # NTFY_TOKEN=... for the contact point above.
  systemd.services.grafana.serviceConfig.EnvironmentFile = [
    config.age.secrets.ntfy-homeserver.path
  ];

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
