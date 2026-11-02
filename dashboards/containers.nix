# Containers and services: what is using the memory and CPU, from cAdvisor
# (prometheus.nix), by systemd unit.
#
# Containers run with --cgroups=split, inside their own podman-<name>.service
# (see splitCgroupContainers in prometheus.nix), so a container is that unit's
# cgroup and is named from it. cAdvisor's own podman support cannot read this
# podman's storage and names nothing.
{ datasource }:
let
  d = import ./lib.nix { inherit datasource; };
  inherit (d) pos;

  # `fn` wraps the bare selector (in rate() and the like) before the label is
  # lifted out: a range can only follow a selector, not label_replace().
  byUnit =
    selector: label: regex: fn: m:
    ''label_replace(${fn "${m}{${selector}}"}, "${label}", "$1", "id", "${regex}")'';

  # The rest of podman-* are podman's own oneshots -- network and volume
  # setup, and the auto-update/prune/clean-transient/restart timers' units.
  containers =
    byUnit
      ''id=~"/system.slice/podman-[^/]+[.]service", id!~"/system.slice/podman-(network-.*|volume-.*|auto-update|prune|clean-transient|restart)[.]service"''
      "name"
      "/system.slice/podman-(.+)[.]service";
  services = byUnit ''id=~"/system.slice/[^/]+[.]service"'' "unit" "/system.slice/(.+)[.]service";

  same = m: m;
  cpu = m: "rate(${m}[$__rate_interval])";
  overRange = m: "increase(${m}[$__range])";
in
d.dashboard {
  uid = "containers";
  title = "Containers & services";
  from = "now-6h";
  panels = [
    (d.stat "Containers" (pos 0 0 6 4) "none" "count(${containers same "container_last_seen"})")
    (d.stat "Container memory" (pos 6 0 6
      4
    ) "bytes" "sum(${containers same "container_memory_working_set_bytes"})")
    (d.alarm "OOM kills (range)" (pos 12 0 6
      4
    ) "none" "sum(increase(node_vmstat_oom_kill[$__range])) or vector(0)" 1)
    (d.stat "Started in the last hour" (pos 18 0 6
      4
    ) "none" "count(time() - ${containers same "container_start_time_seconds"} < 3600) or vector(0)")

    (d.row "Containers" 4)
    (d.timeseries "Memory" (pos 0 5 12 9) "bytes" [
      [
        "max by (name) (${containers same "container_memory_working_set_bytes"})"
        "{{name}}"
      ]
    ])
    (d.timeseries "CPU" (pos 12 5 12 9) "percentunit" [
      [
        "sum by (name) (${containers cpu "container_cpu_usage_seconds_total"})"
        "{{name}}"
      ]
    ])
    # No per-container network: cAdvisor only reads network stats for
    # containers it recognises itself, not plain units -- and qbittorrent,
    # prowlarr and flaresolverr share gluetun's network namespace anyway.
    (d.ranking "Memory now" (pos 0 14 12
      8
    ) "bytes" "max by (name) (${containers same "container_memory_working_set_bytes"})" "{{name}}")
    (d.ranking "CPU over the range" (pos 12 14 12
      8
    ) "s" "sum by (name) (${containers overRange "container_cpu_usage_seconds_total"})" "{{name}}")

    (d.row "Services" 22)
    (d.ranking "Memory now (top 15)" (pos 0 23 12 12) "bytes"
      "topk(15, max by (unit) (${services same "container_memory_working_set_bytes"}))"
      "{{unit}}"
    )
    (d.ranking "CPU over the range (top 15)" (pos 12 23 12 12) "s"
      "topk(15, sum by (unit) (${services overRange "container_cpu_usage_seconds_total"}))"
      "{{unit}}"
    )
    (d.timeseries "Memory (top 10)" (pos 0 35 12 9) "bytes" [
      [
        "topk(10, max by (unit) (${services same "container_memory_working_set_bytes"}))"
        "{{unit}}"
      ]
    ])
    (d.timeseries "CPU (top 10)" (pos 12 35 12 9) "percentunit" [
      [
        "topk(10, sum by (unit) (${services cpu "container_cpu_usage_seconds_total"}))"
        "{{unit}}"
      ]
    ])
    # ZFS does its I/O in its own kernel threads, so reads and writes on the
    # pool are not charged to the service that asked for them; this is the
    # root disk's share only.
    (d.timeseries "Disk I/O (top 10)" (pos 0 44 24 9) "Bps" [
      [
        "topk(10, sum by (unit) (${services cpu "container_fs_reads_bytes_total"}) + sum by (unit) (${services cpu "container_fs_writes_bytes_total"}))"
        "{{unit}}"
      ]
    ])
  ];
}
