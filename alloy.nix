{ config, ... }:
# Ships the systemd journal into Loki. Everything on this box logs there --
# native services directly, the arr containers through docker's journald log
# driver -- so the journal is the only source needed.
let
  # Alloy's UI: the pipeline graph and per-component health. Its default
  # anyway, spelled out so the listener and the registry entry share it.
  port = 12345;
  loki = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";
in
{
  services.alloy = {
    enable = true;
    # Same as grafana.nix's analytics.reporting_enabled = false.
    extraFlags = [
      "--disable-reporting"
      "--server.http.listen-addr=127.0.0.1:${toString port}"
    ];
  };

  # The module reads /etc/alloy, so a switch reloads this instead of
  # restarting.
  environment.etc."alloy/config.alloy".text = ''
    // Journal fields only exist as __journal_* until promoted to labels here.
    // Kept to a handful: every distinct label combination is its own stream in
    // Loki, so per-message fields like PID belong in the line, not the labels.
    loki.relabel "journal" {
      forward_to = []

      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }
      // Podman runs each container's --health-cmd in a transient unit named
      // <container id>-<random>.service, and the random part is new on every
      // container start -- a fresh, unreadable stream each time. One name.
      rule {
        source_labels = ["__journal__systemd_unit"]
        regex         = "[0-9a-f]{64}-[0-9a-f]+\\.service"
        target_label  = "unit"
        replacement   = "podman-healthcheck.service"
      }
      // Docker's journald driver sets CONTAINER_NAME; everything else lacks it.
      rule {
        source_labels = ["__journal_container_name"]
        target_label  = "container"
      }
      // Kernel and other unit-less messages are told apart by this instead.
      rule {
        source_labels = ["__journal_syslog_identifier"]
        target_label  = "identifier"
      }
      rule {
        source_labels = ["__journal_priority_keyword"]
        target_label  = "level"
      }
    }

    loki.source.journal "journal" {
      forward_to    = [loki.write.local.receiver]
      relabel_rules = loki.relabel.journal.rules
      labels        = { job = "systemd-journal", host = "${config.networking.hostName}" }
      // Matches Loki's reject_old_samples_max_age: the first start backfills
      // a week instead of having older entries bounce.
      max_age       = "168h"
    }

    loki.write "local" {
      endpoint {
        url = "${loki}/loki/api/v1/push"
      }
    }
  '';

  shlam.services.alloy = {
    inherit port;
    dashboard = {
      title = "Alloy";
      group = "Infrastructure";
      order = 25;
      icon = "alloy.svg";
      description = "Log Shipping";
    };
  };
}
