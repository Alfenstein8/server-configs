# Homeserver overview: what is wrong right now, the journal (through Loki), and
# whether the monitoring itself is still working. Node Exporter Full stays the
# place for host metrics in depth.
{ prometheus, loki }:
let
  prom = {
    type = "prometheus";
    uid = prometheus;
  };
  logs = {
    type = "loki";
    uid = loki;
  };

  pos = x: y: w: h: {
    inherit
      x
      y
      w
      h
      ;
  };

  panel =
    type: title: gridPos: datasource: targets: extra:
    {
      inherit
        type
        title
        gridPos
        datasource
        ;
      targets = map (t: { inherit datasource; } // t) targets;
    }
    // extra;

  # Green below `red`, red from it -- for counts where anything above 0 is bad.
  thresholds = red: {
    mode = "absolute";
    steps = [
      {
        color = "green";
        value = null;
      }
      {
        color = "red";
        value = red;
      }
    ];
  };

  stat =
    title: gridPos: unit: expr: red:
    panel "stat" title gridPos prom
      [
        {
          refId = "A";
          inherit expr;
          instant = true;
        }
      ]
      {
        fieldConfig = {
          defaults = {
            inherit unit;
            thresholds = thresholds red;
          };
          overrides = [ ];
        };
        options = {
          colorMode = "background";
          graphMode = "none";
          reduceOptions.calcs = [ "lastNotNull" ];
        };
      };

  row = title: y: {
    type = "row";
    inherit title;
    gridPos = pos 0 y 24 1;
    collapsed = false;
    panels = [ ];
  };

  # Every log query goes through the two variables at the top of the
  # dashboard. "All" is .*, which also matches the few lines without a unit.
  stream = extra: ''{job="systemd-journal", unit=~"$unit"${extra}} |~ "(?i)$search"'';

  # Loki normalises the journal's priority keywords (err -> error, and so on);
  # the short forms are kept in case a source sends them unnormalised.
  problemLevels = "emerg|alert|crit|critical|err|error|warn|warning|fatal";

  logPanel =
    title: gridPos: expr:
    panel "logs" title gridPos logs
      [
        {
          refId = "A";
          inherit expr;
          queryType = "range";
        }
      ]
      {
        options = {
          showTime = true;
          wrapLogMessage = true;
          enableLogDetails = true;
          sortOrder = "Descending";
          dedupStrategy = "none";
        };
      };
in
{
  uid = "homeserver";
  title = "Homeserver";
  tags = [ "homeserver" ];
  schemaVersion = 39;
  editable = false;
  time = {
    from = "now-6h";
    to = "now";
  };
  refresh = "1m";

  templating.list = [
    {
      name = "unit";
      label = "Unit";
      type = "query";
      datasource = logs;
      query = ''label_values({job="systemd-journal"}, unit)'';
      refresh = 2; # re-read on time range change, so new units show up
      multi = true;
      includeAll = true;
      allValue = ".*";
      current = {
        text = "All";
        value = "$__all";
      };
      sort = 1;
    }
    {
      name = "search";
      label = "Search (regex)";
      type = "textbox";
      query = "";
      current = {
        text = "";
        value = "";
      };
    }
  ];

  panels = [
    (row "Now" 0)
    (panel "alertlist" "Firing alerts" (pos 0 1 9 8) null [ ] {
      options = {
        viewMode = "list";
        groupMode = "default";
        showInstances = true;
        maxItems = 20;
        sortOrder = 1;
        dashboardAlerts = false;
        stateFilter = {
          firing = true;
          pending = true;
          error = true;
          noData = false;
          normal = false;
        };
      };
    })
    (stat "Failed units" (pos 9 1 3
      4
    ) "none" ''count(node_systemd_unit_state{state="failed"} == 1) or vector(0)'' 1)
    (panel "stat" "ZFS pools" (pos 9 5 3 4) prom
      [
        {
          refId = "A";
          expr = ''max by (zpool) (node_zfs_zpool_state{state="online"})'';
          legendFormat = "{{zpool}}";
          instant = true;
        }
      ]
      {
        fieldConfig = {
          defaults = {
            mappings = [
              {
                type = "value";
                options = {
                  "1" = {
                    text = "ONLINE";
                    color = "green";
                  };
                  "0" = {
                    text = "NOT ONLINE";
                    color = "red";
                  };
                };
              }
            ];
            color.mode = "thresholds";
            # The inverse of `thresholds`: 1 (online) is the good value.
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
    (panel "table" "Failed units" (pos 12 1 5 8) prom
      [
        {
          refId = "A";
          expr = ''node_systemd_unit_state{state="failed"} == 1'';
          instant = true;
          format = "table";
        }
      ]
      {
        transformations = [
          {
            id = "filterFieldsByName";
            options.include.names = [ "name" ];
          }
        ];
        fieldConfig = {
          defaults.noValue = "None";
          overrides = [ ];
        };
      }
    )
    (panel "bargauge" "Disk usage" (pos 17 1 7 8) prom
      [
        {
          refId = "A";
          # Same filesystems as the "Filesystem almost full" alert.
          expr = ''100 * (1 - node_filesystem_avail_bytes{fstype!~"tmpfs|ramfs|overlay|squashfs|nsfs|fuse.*"} / node_filesystem_size_bytes)'';
          legendFormat = "{{mountpoint}}";
          instant = true;
        }
      ]
      {
        fieldConfig = {
          defaults = {
            unit = "percent";
            min = 0;
            max = 100;
            thresholds = {
              mode = "absolute";
              steps = [
                {
                  color = "green";
                  value = null;
                }
                {
                  color = "orange";
                  value = 80;
                }
                {
                  color = "red";
                  value = 90;
                }
              ];
            };
          };
          overrides = [ ];
        };
        options = {
          orientation = "horizontal";
          displayMode = "gradient";
          showUnfilled = true;
          reduceOptions.calcs = [ "lastNotNull" ];
        };
      }
    )

    (row "Logs" 9)
    (panel "timeseries" "Log lines per unit" (pos 0 10 24 7) logs
      [
        {
          refId = "A";
          expr = "sum by (unit) (count_over_time(${stream ""} [$__interval]))";
          legendFormat = "{{unit}}";
          queryType = "range";
        }
      ]
      {
        fieldConfig = {
          defaults.custom = {
            drawStyle = "bars";
            fillOpacity = 80;
            stacking.mode = "normal";
          };
          overrides = [ ];
        };
        options.legend = {
          displayMode = "table";
          placement = "right";
          calcs = [ "sum" ];
          sortBy = "Total";
          sortDesc = true;
        };
      }
    )
    (logPanel "Errors and warnings" (pos 0 17 24 10) (stream '', level=~"${problemLevels}"''))
    (logPanel "All logs" (pos 0 27 24 14) (stream ""))

    (row "Monitoring" 41)
    (stat "Scrape targets down" (pos 0 42 4 4) "none" "count(up == 0) or vector(0)" 1)
    (stat "Log entries dropped (range)" (pos 4 42 4
      4
    ) "none" "sum(increase(loki_write_dropped_entries_total[$__range])) or vector(0)" 1)
    (panel "timeseries" "Journal lines: read by Alloy vs received by Loki" (pos 8 42 16 8) prom
      [
        {
          refId = "A";
          expr = "sum(rate(loki_source_journal_target_lines_total[$__rate_interval]))";
          legendFormat = "read (Alloy)";
        }
        {
          refId = "B";
          expr = "sum(rate(loki_distributor_lines_received_total[$__rate_interval]))";
          legendFormat = "received (Loki)";
        }
      ]
      {
        fieldConfig = {
          defaults.unit = "short";
          overrides = [ ];
        };
      }
    )
    (panel "stat" "Prometheus series" (pos 0 46 4 4) prom
      [
        {
          refId = "A";
          expr = "prometheus_tsdb_head_series";
          instant = true;
        }
      ]
      {
        options = {
          colorMode = "none";
          graphMode = "area";
          reduceOptions.calcs = [ "lastNotNull" ];
        };
      }
    )
    (panel "stat" "Firing alerts" (pos 4 46 4 4) prom
      [
        {
          refId = "A";
          expr = ''sum(grafana_alerting_alerts{state="alerting"}) or vector(0)'';
          instant = true;
        }
      ]
      {
        fieldConfig = {
          defaults.thresholds = thresholds 1;
          overrides = [ ];
        };
        options = {
          colorMode = "background";
          graphMode = "none";
          reduceOptions.calcs = [ "lastNotNull" ];
        };
      }
    )

    # Node Exporter Full has no ARC panels, so they live here.
    (row "ZFS ARC" 50)
    (panel "timeseries" "ARC size and swap" (pos 0 51 12 8) prom
      [
        {
          refId = "A";
          expr = "node_zfs_arc_size";
          legendFormat = "size";
        }
        {
          refId = "B";
          expr = "node_zfs_arc_c_max";
          legendFormat = "limit (zfs_arc_max)";
        }
        {
          refId = "C";
          expr = "node_memory_SwapTotal_bytes - node_memory_SwapFree_bytes";
          legendFormat = "swap used";
        }
      ]
      {
        fieldConfig = {
          defaults = {
            unit = "bytes";
            min = 0;
          };
          overrides = [ ];
        };
      }
    )
    (panel "timeseries" "ARC hit rate" (pos 12 51 12 8) prom
      [
        {
          refId = "A";
          # Over a fixed hour rather than $__rate_interval: on an idle pool a
          # short window has no reads at all, and 0/0 leaves gaps.
          expr = "sum(rate(node_zfs_arc_hits[1h])) / (sum(rate(node_zfs_arc_hits[1h])) + sum(rate(node_zfs_arc_misses[1h])))";
          legendFormat = "all";
        }
        {
          refId = "B";
          expr = "rate(node_zfs_arc_demand_data_hits[1h]) / (rate(node_zfs_arc_demand_data_hits[1h]) + rate(node_zfs_arc_demand_data_misses[1h]))";
          legendFormat = "file data";
        }
        {
          refId = "C";
          expr = "rate(node_zfs_arc_demand_metadata_hits[1h]) / (rate(node_zfs_arc_demand_metadata_hits[1h]) + rate(node_zfs_arc_demand_metadata_misses[1h]))";
          legendFormat = "metadata";
        }
      ]
      {
        fieldConfig = {
          defaults = {
            unit = "percentunit";
            max = 1;
          };
          overrides = [ ];
        };
      }
    )
  ];
}
