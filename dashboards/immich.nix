# Immich dashboard, built from what Immich 3.2 actually exports. Community
# dashboards target older metric names and show nothing here.
#
# Immich (through OpenTelemetry) puts the interesting part in the metric NAME --
# immich_jobs_<job>_<status>_total, immich_queues_<queue>_active,
# immich_<class>_<method>_duration_* -- so most queries select by name regex and
# lift that part into a label with label_replace. rate()/increase() drop
# __name__, so where the label is needed after them the selector is wrapped in
# a subquery: label first, then rate over [range:step].
#
# There are no HTTP request metrics: Immich exports none, IMMICH_TELEMETRY_INCLUDE
# = all notwithstanding.
{ datasource }:
let
  ds = {
    type = "prometheus";
    uid = datasource;
  };

  target = expr: legendFormat: {
    refId = "A";
    datasource = ds;
    inherit expr legendFormat;
  };

  panel =
    type: title: gridPos: unit: targets: extra:
    {
      inherit type title gridPos;
      datasource = ds;
      targets = map (t: t // { refId = t.refId or "A"; }) targets;
      fieldConfig = {
        defaults = { inherit unit; };
        overrides = [ ];
      };
    }
    // extra;

  stat =
    title: x: unit: expr:
    panel "stat" title
      {
        inherit x;
        y = 0;
        w = 6;
        h = 4;
      }
      unit
      [ ((target expr "") // { instant = true; }) ]
      { options.reduceOptions.calcs = [ "lastNotNull" ]; };

  timeseries =
    title: gridPos: unit: targets:
    panel "timeseries" title gridPos unit targets { };

  # Horizontal bars, largest first, as of the end of the dashboard's range.
  ranking =
    title: gridPos: unit: expr:
    panel "bargauge" title gridPos unit
      [ ((target "sort_desc(${expr})" "{{method}}") // { instant = true; }) ]
      {
        options = {
          orientation = "horizontal";
          displayMode = "gradient";
          showUnfilled = true;
          reduceOptions.calcs = [ "lastNotNull" ];
        };
      };

  jobs = status: ''{__name__=~"immich_jobs_.+_${status}_total"}'';

  # Per-method timing histograms, method lifted out of the name. `part` is sum
  # or count; `.*` covers whatever unit suffix the exporter adds.
  methods =
    part:
    ''label_replace({__name__=~"immich_.+_duration.*_${part}"}, "method", "$1", "__name__", "immich_(.+)_duration.*_${part}")'';
  overRange = part: "sum by (method) (increase(${methods part}[$__range:1m]))";
in
{
  uid = "immich";
  title = "Immich";
  tags = [ "immich" ];
  schemaVersion = 39;
  editable = false;
  time = {
    from = "now-24h";
    to = "now";
  };
  refresh = "1m";

  panels = [
    (stat "Users" 0 "none" "max(immich_users_total)")
    (stat "Active jobs" 6 "none" ''sum({__name__=~"immich_queues_.+_active"})'')
    (stat "Failed jobs (range)" 12 "none" "sum(increase(${jobs "failed"}[$__range])) or vector(0)")
    (stat "Memory" 18 "bytes" "sum(process_memory_usage{job=\"immich\"})")

    (timeseries "Active jobs per queue"
      {
        x = 0;
        y = 4;
        w = 12;
        h = 8;
      }
      "none"
      [
        (target ''label_replace({__name__=~"immich_queues_.+_active"}, "queue", "$1", "__name__", "immich_queues_(.+)_active")'' "{{queue}}")
      ]
    )
    (timeseries "Jobs finished"
      {
        x = 12;
        y = 4;
        w = 12;
        h = 8;
      }
      "ops"
      (
        map
          (s: {
            refId = s;
            datasource = ds;
            expr = "sum(rate(${jobs s}[$__rate_interval]))";
            legendFormat = s;
          })
          [
            "success"
            "skipped"
            "failed"
          ]
      )
    )

    (ranking "Failed jobs by type (range)"
      {
        x = 0;
        y = 12;
        w = 12;
        h = 8;
      }
      "none"
      ''sum by (method) (increase(label_replace(${jobs "failed"}, "method", "$1", "__name__", "immich_jobs_(.+)_failed_total")[$__range:1m])) > 0''
    )
    (timeseries "CPU"
      {
        x = 12;
        y = 12;
        w = 6;
        h = 8;
      }
      "percentunit"
      [
        (target ''sum by (worker) (rate(process_cpu_time_total{job="immich"}[$__rate_interval]))'' "{{worker}}")
      ]
    )
    (timeseries "Memory" {
      x = 18;
      y = 12;
      w = 6;
      h = 8;
    } "bytes" [ (target ''sum by (worker) (process_memory_usage{job="immich"})'' "{{worker}}") ])

    # Where the time goes: total time spent per method, and the slowest calls
    # on average. Both across the API and the microservices worker.
    (ranking "Most time spent (range)" {
      x = 0;
      y = 20;
      w = 12;
      h = 10;
    } "ms" "topk(15, ${overRange "sum"})")
    (ranking "Slowest on average (range)" {
      x = 12;
      y = 20;
      w = 12;
      h = 10;
    } "ms" "topk(15, ${overRange "sum"} / (${overRange "count"} > 0))")
  ];
}
