# Caddy: traffic, errors and latency per virtual host. Every service with a URL
# is behind it, so this is the one place that sees all of them answer.
#
# Caddy times each handler a request passes through, so one request through a
# subroute and a reverse_proxy is counted under both. Queries take the busiest
# handler per host (max by host over a sum by host, handler) rather than adding
# them up, which would count such requests twice.
{ datasource }:
let
  d = import ./lib.nix { inherit datasource; };
  inherit (d) pos;

  perHost =
    selector: fn:
    "max by (host) (sum by (host, handler) (${fn "caddy_http_request_duration_seconds_count${selector}"}))";
  rate = m: "rate(${m}[$__rate_interval])";
  increase = m: "increase(${m}[$__range])";
in
d.dashboard {
  uid = "caddy";
  title = "Caddy";
  panels = [
    (d.stat "Requests/s" (pos 0 0 6 4) "reqps" "sum(${perHost "" rate})")
    (d.alarm "5xx responses (range)" (pos 6 0 6
      4
    ) "none" "sum(${perHost ''{code=~"5.."}'' increase}) or vector(0)" 1)
    (d.stat "In flight" (pos 12 0 6 4) "none" "sum(caddy_http_requests_in_flight)")
    (d.alarm "Last config reload" (pos 18 0 6 4) "none"
      # 1 = success. Inverted so a failed reload (0) shows red.
      "1 - max(caddy_config_last_reload_successful)"
      1
    )

    (d.timeseries "Requests by host" (pos 0 4 12 9) "reqps" [
      [
        (perHost "" rate)
        "{{host}}"
      ]
    ])
    (d.timeseries "5xx by host" (pos 12 4 12 9) "reqps" [
      [
        "${perHost ''{code=~"5.."}'' rate} > 0"
        "{{host}}"
      ]
    ])

    (d.timeseries "p95 response time by host" (pos 0 13 12 9) "s" [
      [
        "histogram_quantile(0.95, max by (host, le) (sum by (host, handler, le) (rate(caddy_http_request_duration_seconds_bucket[$__rate_interval]))))"
        "{{host}}"
      ]
    ])
    (d.timeseries "Bytes served by host" (pos 12 13 12 9) "Bps" [
      [
        "max by (host) (sum by (host, handler) (rate(caddy_http_response_size_bytes_sum[$__rate_interval])))"
        "{{host}}"
      ]
    ])

    (d.ranking "Busiest hosts (range)" (pos 0 22 12 9) "none" (perHost "" increase) "{{host}}")
    (d.ranking "Most 5xx (range)" (pos 12 22 12
      9
    ) "none" "${perHost ''{code=~"5.."}'' increase} > 0" "{{host}}")
  ];
}
