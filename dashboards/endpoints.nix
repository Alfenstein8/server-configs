# Endpoints: the blackbox probes from blackbox.nix -- every registry URL through
# Caddy, plus DNS through AdGuard.
{ datasource }:
let
  d = import ./lib.nix { inherit datasource; };
  inherit (d) pos;

  # Days until the served certificate expires, one series per domain (every
  # *.shlambert.top host serves the same wildcard).
  certDays = ''min by (domain) (label_replace((probe_ssl_earliest_cert_expiry - time()) / 86400, "domain", "$1", "instance", "https://[^.]+[.]([^:/]+).*"))'';

  upDown = {
    mappings = [
      {
        type = "value";
        options = {
          "1" = {
            text = "UP";
            color = "green";
          };
          "0" = {
            text = "DOWN";
            color = "red";
          };
        };
      }
    ];
    color.mode = "thresholds";
    thresholds = {
      mode = "absolute";
      steps = [
        {
          color = "red";
          value = null;
        }
        {
          color = "green";
          value = 1;
        }
      ];
    };
  };
in
d.dashboard {
  uid = "endpoints";
  title = "Endpoints";
  panels = [
    (d.alarm "Endpoints down" (pos 0 0 6 4) "none" "count(probe_success == 0) or vector(0)" 1)
    (d.stat "Endpoints probed" (pos 6 0 6 4) "none" "count(probe_success)")
    (d.panel "stat" "Certificate expires in" (pos 12 0 6 4) "d"
      (d.instant [
        [
          certDays
          "{{domain}}"
        ]
      ])
      {
        fieldConfig = {
          defaults = {
            unit = "d";
            decimals = 0;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "red";
                  value = null;
                }
                {
                  color = "orange";
                  value = 21;
                }
                {
                  color = "green";
                  value = 30;
                }
              ];
            };
          };
          overrides = [ ];
        };
        options = {
          colorMode = "background";
          graphMode = "none";
          textMode = "value_and_name";
          reduceOptions.calcs = [ "lastNotNull" ];
        };
      }
    )
    (d.stat "DNS answer time" (pos 18 0 6 4) "s" ''max(probe_duration_seconds{job="blackbox-dns"})'')

    (d.panel "state-timeline" "Up / down" (pos 0 4 24 14) "none"
      (d.targets [
        [
          "max by (service) (probe_success)"
          "{{service}}"
        ]
      ])
      {
        fieldConfig = {
          defaults = upDown;
          overrides = [ ];
        };
        options = {
          showValue = "never";
          mergeValues = true;
          rowHeight = 0.8;
          legend.showLegend = false;
        };
      }
    )

    (d.ranking "Response time" (pos 0 18 12
      12
    ) "s" ''max by (service) (probe_duration_seconds{job="blackbox-https"})'' "{{service}}")
    (d.timeseries "Response time" (pos 12 18 12 12) "s" [
      [
        ''max by (service) (probe_duration_seconds{job="blackbox-https"})''
        "{{service}}"
      ]
    ])
    # 0 = no HTTP response at all (connection or TLS failure).
    (d.panel "table" "HTTP status" (pos 0 30 24 10) "none"
      [
        {
          refId = "A";
          datasource = d.ds;
          expr = "max by (service, instance) (probe_http_status_code)";
          instant = true;
          format = "table";
        }
      ]
      {
        transformations = [
          {
            id = "organize";
            options = {
              excludeByName.Time = true;
              renameByName.Value = "status";
            };
          }
        ];
      }
    )
  ];
}
