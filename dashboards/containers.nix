# Containers and services: what is using the memory and CPU, from cAdvisor
# (prometheus.nix). Podman containers carry a `name`; native services are
# cgroups under /system.slice, named here by their unit.
{ datasource }:
let
  d = import ./lib.nix { inherit datasource; };
  inherit (d) pos;

  containers = m: ''${m}{name!=""}'';
  # Named by unit, e.g. immich-server. podman-<name>.service units are left
  # out: the container itself runs in its own scope, so they hold only the
  # podman CLI waiting on it.
  #
  # `fn` wraps the bare selector (in rate() and the like) before the label is
  # lifted out: a range can only follow a selector, not label_replace().
  services =
    fn: m:
    ''label_replace(${fn ''${m}{id=~"/system.slice/[^/]+[.]service", id!~"/system.slice/podman-.*"}''}, "unit", "$1", "id", "/system.slice/(.+)[.]service")'';
  now = services (m: m);

  cpu = m: "rate(${m}[$__rate_interval])";
  overRange = m: "increase(${m}[$__range])";
in
d.dashboard {
  uid = "containers";
  title = "Containers & services";
  from = "now-6h";
  panels = [
    (d.stat "Containers running" (pos 0 0 6 4) "none" ''count(container_last_seen{name!=""})'')
    (d.stat "Container memory" (pos 6 0 6
      4
    ) "bytes" "sum(${containers "container_memory_working_set_bytes"})")
    (d.alarm "OOM kills (range)" (pos 12 0 6
      4
    ) "none" "sum(increase(node_vmstat_oom_kill[$__range])) or vector(0)" 1)
    (d.stat "Started in the last hour" (pos 18 0 6
      4
    ) "none" ''count(time() - container_start_time_seconds{name!=""} < 3600) or vector(0)'')

    (d.row "Containers" 4)
    (d.timeseries "Memory" (pos 0 5 12 9) "bytes" [
      [
        "max by (name) (${containers "container_memory_working_set_bytes"})"
        "{{name}}"
      ]
    ])
    (d.timeseries "CPU" (pos 12 5 12 9) "percentunit" [
      [
        "sum by (name) (${cpu (containers "container_cpu_usage_seconds_total")})"
        "{{name}}"
      ]
    ])
    (d.timeseries "Network received" (pos 0 14 12 8) "Bps" [
      [
        "sum by (name) (${cpu (containers "container_network_receive_bytes_total")}) > 0"
        "{{name}}"
      ]
    ])
    (d.timeseries "Network sent" (pos 12 14 12 8) "Bps" [
      [
        "sum by (name) (${cpu (containers "container_network_transmit_bytes_total")}) > 0"
        "{{name}}"
      ]
    ])

    (d.row "Services" 22)
    (d.ranking "Memory now (top 15)" (pos 0 23 12
      12
    ) "bytes" "topk(15, max by (unit) (${now "container_memory_working_set_bytes"}))" "{{unit}}")
    (d.ranking "CPU over the range (top 15)" (pos 12 23 12 12) "s"
      "topk(15, sum by (unit) (${services overRange "container_cpu_usage_seconds_total"}))"
      "{{unit}}"
    )
    (d.timeseries "Memory (top 10)" (pos 0 35 12 9) "bytes" [
      [
        "topk(10, max by (unit) (${now "container_memory_working_set_bytes"}))"
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
