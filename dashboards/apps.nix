# Apps that export their own metrics but don't warrant a dashboard each.
# One row per app; process_* is the Go client's standard set, which they all
# have, told apart by `job`.
{ datasource }:
let
  d = import ./lib.nix { inherit datasource; };
  inherit (d) pos;

  memory =
    job: gridPos:
    d.timeseries "Memory" gridPos "bytes" [
      [
        ''process_resident_memory_bytes{job="${job}"}''
        "resident"
      ]
    ];
in
d.dashboard {
  uid = "apps";
  title = "Apps";
  from = "now-7d";
  panels = [
    (d.row "Headscale" 0)
    (d.stat "Nodes" (pos 0 1 4 4) "none" "max(headscale_nodestore_nodes)")
    (d.stat "Map sessions ended (range)" (pos 0 5 4
      4
    ) "none" "sum(increase(headscale_mapresponse_ended_total[$__range])) or vector(0)")
    # Every change pushed to the tailnet is a map response; keepalives aside,
    # a spike here is nodes churning.
    (d.timeseries "Map responses sent" (pos 4 1 12 8) "ops" [
      [
        "sum by (type) (rate(headscale_mapresponse_sent_total[$__rate_interval]))"
        "{{type}}"
      ]
    ])
    (memory "headscale" (pos 16 1 8 8))

    (d.row "Forgejo" 9)
    (d.stat "Repositories" (pos 0 10 4 4) "none" "max(gitea_repositories)")
    (d.stat "Users" (pos 4 10 4 4) "none" "max(gitea_users)")
    (d.stat "Open issues" (pos 8 10 4 4) "none" "max(gitea_issues_open)")
    (d.stat "Mirrors" (pos 12 10 4 4) "none" "max(gitea_mirrors)")
    (d.timeseries "Repositories" (pos 0 14 16 8) "none" [
      [
        "max(gitea_repositories)"
        "repositories"
      ]
      [
        "max(gitea_releases)"
        "releases"
      ]
    ])
    (memory "forgejo" (pos 16 10 8 12))
  ];
}
