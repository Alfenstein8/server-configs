# Panel builders for the Prometheus-only dashboards in this directory.
# homeserver.nix and immich.nix predate it and keep their own copies.
#
#   let d = import ./lib.nix { inherit datasource; }; in
#   d.dashboard { uid = "x"; title = "X"; panels = [ (d.stat ...) ]; }
#
# Every panel takes its gridPos explicitly (d.pos x y w h): Grafana's grid is 24
# wide, and leaving placement to it shuffles panels on every reprovision.
{ datasource }:
rec {
  ds = {
    type = "prometheus";
    uid = datasource;
  };

  pos = x: y: w: h: {
    inherit
      x
      y
      w
      h
      ;
  };

  # [ [expr legend] ... ] -> targets with refIds A, B, C, ...
  targets =
    queries:
    builtins.genList (
      i:
      let
        q = builtins.elemAt queries i;
      in
      {
        refId = builtins.substring i 1 "ABCDEFGHIJ";
        datasource = ds;
        expr = builtins.elemAt q 0;
        legendFormat = builtins.elemAt q 1;
      }
    ) (builtins.length queries);

  instant = queries: map (t: t // { instant = true; }) (targets queries);

  panel =
    type: title: gridPos: unit: tgts: extra:
    {
      inherit type title gridPos;
      datasource = ds;
      targets = tgts;
      fieldConfig = {
        defaults = { inherit unit; };
        overrides = [ ];
      };
    }
    // extra;

  # Green below `red`, red from it.
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
    title: gridPos: unit: expr:
    panel "stat" title gridPos unit
      (instant [
        [
          expr
          ""
        ]
      ])
      {
        options = {
          colorMode = "none";
          graphMode = "none";
          reduceOptions.calcs = [ "lastNotNull" ];
        };
      };

  # A stat that turns red at `red` -- for counts where more is bad.
  alarm =
    title: gridPos: unit: expr: red:
    panel "stat" title gridPos unit
      (instant [
        [
          expr
          ""
        ]
      ])
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

  timeseries =
    title: gridPos: unit: queries:
    panel "timeseries" title gridPos unit (targets queries) {
      options.legend = {
        displayMode = "table";
        placement = "right";
        calcs = [
          "mean"
          "max"
        ];
        sortBy = "Max";
        sortDesc = true;
      };
    };

  # Horizontal bars, largest first, as of the end of the range.
  ranking =
    title: gridPos: unit: expr: legend:
    panel "bargauge" title gridPos unit
      (instant [
        [
          "sort_desc(${expr})"
          legend
        ]
      ])
      {
        options = {
          orientation = "horizontal";
          displayMode = "gradient";
          showUnfilled = true;
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

  dashboard =
    {
      uid,
      title,
      panels,
      from ? "now-24h",
    }:
    {
      inherit uid title panels;
      tags = [ "homeserver" ];
      schemaVersion = 39;
      editable = false;
      time = {
        inherit from;
        to = "now";
      };
      refresh = "1m";
    };
}
