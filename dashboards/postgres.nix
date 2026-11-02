# PostgreSQL, the shared instance (immich, dawarich). Database growth matters
# most here: it lives on the root disk, not the ZFS pool.
{ datasource }:
let
  d = import ./lib.nix { inherit datasource; };
  inherit (d) pos;
  # Postgres' own template databases are noise.
  dbs = ''datname!~"template.*|"'';
in
d.dashboard {
  uid = "postgres";
  title = "PostgreSQL";
  from = "now-7d";
  panels = [
    (d.alarm "Down" (pos 0 0 4 4) "none" "1 - max(pg_up)" 1)
    (d.stat "Total size" (pos 4 0 5 4) "bytes" "sum(pg_database_size_bytes{${dbs}})")
    (d.stat "Connections" (pos 9 0 5 4) "none" "sum(pg_stat_database_numbackends)")
    (d.stat "Max connections" (pos 14 0 5 4) "none" "max(pg_settings_max_connections)")
    (d.alarm "Deadlocks (range)" (pos 19 0 5
      4
    ) "none" "sum(increase(pg_stat_database_deadlocks[$__range])) or vector(0)" 1)

    (d.timeseries "Database size" (pos 0 4 12 9) "bytes" [
      [
        "pg_database_size_bytes{${dbs}}"
        "{{datname}}"
      ]
    ])
    (d.timeseries "Connections by database" (pos 12 4 12 9) "none" [
      [
        "pg_stat_database_numbackends{${dbs}}"
        "{{datname}}"
      ]
    ])

    (d.timeseries "Transactions" (pos 0 13 12 9) "ops" [
      [
        "rate(pg_stat_database_xact_commit{${dbs}}[$__rate_interval])"
        "{{datname}} commit"
      ]
      [
        "rate(pg_stat_database_xact_rollback{${dbs}}[$__rate_interval]) > 0"
        "{{datname}} rollback"
      ]
    ])
    # Below ~99% the working set no longer fits in shared_buffers + page cache.
    (d.timeseries "Cache hit ratio" (pos 12 13 12 9) "percentunit" [
      [
        "rate(pg_stat_database_blks_hit{${dbs}}[$__rate_interval]) / (rate(pg_stat_database_blks_hit{${dbs}}[$__rate_interval]) + rate(pg_stat_database_blks_read{${dbs}}[$__rate_interval]))"
        "{{datname}}"
      ]
    ])

    (d.timeseries "Rows written" (pos 0 22 12 9) "ops" [
      [
        "rate(pg_stat_database_tup_inserted{${dbs}}[$__rate_interval])"
        "{{datname}} inserted"
      ]
      [
        "rate(pg_stat_database_tup_updated{${dbs}}[$__rate_interval])"
        "{{datname}} updated"
      ]
      [
        "rate(pg_stat_database_tup_deleted{${dbs}}[$__rate_interval])"
        "{{datname}} deleted"
      ]
    ])
    # A transaction left open blocks vacuum for every table in the database.
    (d.timeseries "Longest open transaction" (pos 12 22 12 9) "s" [
      [
        "max by (datname) (pg_stat_activity_max_tx_duration{${dbs}})"
        "{{datname}}"
      ]
    ])
  ];
}
