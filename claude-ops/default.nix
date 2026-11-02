{
  config,
  lib,
  pkgs,
  ...
}:
# A daily health check by Claude Code, run headless on this box. It reads
# Prometheus, Loki, Grafana (as a Viewer), the journal and /etc/nixos,
# decides whether anything needs
# a human, and posts to the Discord webhook Grafana already uses -- only when
# it does, plus a short all-clear on Mondays so silence means "fine" and not
# "broken". A failed run posts too, and leaves the unit failed, which Grafana's
# "Systemd unit failed" alert also picks up.
#
# Containment, in two layers:
#   * Claude Code: --restricted ignores every settings file and confines the
#     file tools to the working directory (work/, holding only notes.md) plus
#     /etc/nixos; --permission-mode dontAsk refuses anything not in `allowed`
#     below instead of waiting for an answer that never comes. Checked before
#     writing this: a refused command inside `a && b` is caught, as are curl,
#     reads outside those directories, and writes to anything but notes.md.
#   * systemd: its own unprivileged user, read-only filesystem apart from its
#     state directory, no capabilities.
# The prompt also treats log lines as untrusted, since some of them come from
# the internet (Caddy, headscale).
#
# Secrets, each alone in its file and handed over with LoadCredential:
#   claude-ops.age          CLAUDE_CODE_OAUTH_TOKEN for Alfred's subscription,
#                           from `claude setup-token`.
#   claude-ops-grafana.age  a Grafana service-account token with the Viewer
#                           role (Administration -> Users and access ->
#                           Service accounts). Viewer can read dashboards,
#                           alert rules and their state, and change nothing.
#
# Run it by hand: systemctl start claude-ops; journalctl -u claude-ops -f.
# Reports are kept in /var/lib/claude-ops/reports, out of the session's reach.
let
  stateDir = "/var/lib/claude-ops";
  prometheus = "http://127.0.0.1:${toString config.services.prometheus.port}";
  loki = "http://127.0.0.1:${toString config.services.loki.configuration.server.http_listen_port}";

  # Once a day, depth beats speed: in the dry runs Sonnet sometimes skimmed and
  # called a day with 200 Forgejo mirror errors "clean".
  model = "opus";

  # Query helpers with the address fixed inside, so the model can ask
  # Prometheus and Loki anything but cannot point a request anywhere else.
  promq = pkgs.writeShellApplication {
    name = "promq";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      if [ $# -ne 1 ]; then echo "usage: promq '<PromQL>'" >&2; exit 2; fi
      curl -sS --max-time 30 -G ${prometheus}/api/v1/query --data-urlencode "query=$1" |
        jq -r 'if .status != "success" then "error: \(.error)"
               elif .data.resultType == "scalar" or .data.resultType == "string" then .data.result[1]
               elif (.data.result | length) == 0 then "(no data)"
               else .data.result[] |
                 "\(.metric | to_entries | map("\(.key)=\(.value)") | join(" "))  \(if .value then .value[1] else (.values | map(.[1]) | join(",")) end)" end'
    '';
  };
  logq = pkgs.writeShellApplication {
    name = "logq";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
    ];
    text = ''
      if [ $# -lt 1 ]; then echo "usage: logq '<LogQL>' [since=24h] [limit=50]" >&2; exit 2; fi
      curl -sS --max-time 60 -G ${loki}/loki/api/v1/query_range \
        --data-urlencode "query=$1" --data-urlencode "since=''${2:-24h}" \
        --data-urlencode "limit=''${3:-50}" --data-urlencode "direction=backward" |
        jq -r 'if .status != "success" then "error: \(.)"
               elif .data.resultType == "streams" then
                 [.data.result[] | .stream as $s | .values[] | [.[0], ($s.unit // $s.identifier // ""), .[1]]]
                 | sort_by(.[0] | tonumber) | reverse | .[] | "\(.[0] | tonumber / 1e9 | floor | strflocaltime("%m-%d %H:%M:%S")) \(.[1]): \(.[2])"
               else .data.result[] | (.values | map(.[1] | tonumber)) as $v
                 | "\(.metric | to_entries | map("\(.key)=\(.value)") | join(" "))  last=\($v[-1]) min=\($v | min) max=\($v | max) points=\($v | length)" end'
    '';
  };

  # Grafana's HTTP API, GET only, as the Viewer service account. Grafana's
  # enforce_domain redirects any other Host, so the request names it. The
  # token is read here, from a fixed path rather than $CREDENTIALS_DIRECTORY
  # (which a command could override), and never enters the session's
  # environment.
  grafana = config.services.grafana.settings.server;
  grafana-api = pkgs.writeShellApplication {
    name = "grafana-api";
    runtimeInputs = [
      pkgs.curl
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      if [ $# -ne 1 ] || [[ "$1" != /api/* ]]; then
        echo "usage: grafana-api /api/<path>[?query]   (GET only)" >&2; exit 2
      fi
      curl -sS --max-time 30 \
        -H "Authorization: Bearer $(cat /run/credentials/claude-ops.service/grafana)" \
        -H "Host: ${grafana.domain}" \
        "http://127.0.0.1:${toString grafana.http_port}$1" |
        jq . 2>/dev/null | head -c 40000 || true
    '';
  };

  # Everything the session may run or touch. Reads inside the working
  # directory and /etc/nixos need no rule; everything else is refused.
  #
  # Deliberately no grep/head/sort/cat for pipelines: they take file
  # arguments, and a Bash command is not confined the way the Read and Grep
  # tools are -- `head $CREDENTIALS_DIRECTORY/token` would be one rule away.
  allowed = [
    "Bash(promq:*)"
    "Bash(logq:*)"
    "Bash(grafana-api:*)"
    "Bash(systemctl status:*)"
    "Bash(systemctl list-units:*)"
    "Bash(systemctl list-timers:*)"
    "Bash(journalctl:*)"
    "Bash(zpool status:*)"
    "Bash(zpool list:*)"
    "Bash(df:*)"
    "Bash(free:*)"
    # Covers the Write tool too.
    "Edit(./notes.md)"
  ];

  schema = builtins.toJSON {
    type = "object";
    required = [
      "status"
      "summary"
      "findings"
    ];
    properties = {
      status = {
        type = "string";
        enum = [
          "ok"
          "attention"
          "action"
        ];
      };
      summary = {
        type = "string";
        description = "One or two sentences for a phone notification.";
      };
      findings = {
        type = "array";
        items = {
          type = "object";
          required = [
            "severity"
            "title"
            "evidence"
            "next_step"
          ];
          properties = {
            severity = {
              type = "string";
              enum = [
                "info"
                "attention"
                "action"
              ];
            };
            title.type = "string";
            evidence.type = "string";
            next_step.type = "string";
          };
        };
      };
    };
  };

  check = pkgs.writeShellApplication {
    name = "claude-ops-check";
    runtimeInputs = [
      pkgs.claude-code
      pkgs.curl
      pkgs.jq
      pkgs.coreutils
      promq
      logq
      grafana-api
      # For the commands in `allowed`.
      config.systemd.package
      config.boot.zfs.package
      pkgs.procps
    ];
    text = ''
      creds="$CREDENTIALS_DIRECTORY"
      # The webhook stays a plain shell variable: never exported, so the
      # session cannot see it. The env-file format is grafana.nix's.
      webhook=$(sed -n 's/^DISCORD_WEBHOOK_URL=//p' "$creds/discord")

      post() {
        jq -n --arg c "$1" '{content: ($c | .[0:1990]), allowed_mentions: {parse: []}}' |
          curl -sS --max-time 30 -H 'Content-Type: application/json' -d @- "$webhook" >/dev/null
      }

      # The session works in work/, which holds nothing but its notes. Not the
      # state directory itself: that is $HOME, where Claude Code keeps its own
      # config -- which it treats as sensitive and refuses to let a session
      # write next to -- and where the reports live out of the session's reach.
      mkdir -p ${stateDir}/work ${stateDir}/reports
      cd ${stateDir}/work
      touch notes.md
      out="${stateDir}/reports/$(date +%F).json"

      if ! CLAUDE_CODE_OAUTH_TOKEN=$(cat "$creds/token") claude -p \
          "Run today's health check. It is $(date '+%A %F %H:%M %Z')." \
          --append-system-prompt-file ${./prompt.md} \
          --restricted --strict-mcp-config \
          --tools "Bash,Read,Grep,Glob,Edit,Write" \
          --permission-mode dontAsk \
          --allowedTools ${lib.escapeShellArgs allowed} \
          --add-dir /etc/nixos \
          --model ${model} \
          --no-session-persistence \
          --output-format json \
          --json-schema ${lib.escapeShellArg schema} \
          >"$out"; then
        post "⚠️ **homeserver check failed** -- claude exited with an error. journalctl -u claude-ops"
        exit 1
      fi

      if ! jq -e '.structured_output.status' "$out" >/dev/null; then
        post "⚠️ **homeserver check failed** -- no verdict: $(jq -r '.result // .subtype // "unreadable output"' "$out" | head -c 300)"
        exit 1
      fi

      jq -r '"denied: \(.permission_denials | length), cost: \(.total_cost_usd)"' "$out"
      status=$(jq -r '.structured_output.status' "$out")
      echo "status: $status"

      if [ "$status" != ok ]; then
        post "$(jq -r '.structured_output as $r
          | (if $r.status == "action" then "🔴 **homeserver: action needed**" else "🟡 **homeserver: worth a look**" end)
          + "\n" + $r.summary + "\n"
          + ($r.findings | map(select(.severity != "info"))
              | map("\n**\(.title)**\n\(.evidence)\n→ \(.next_step)") | join("\n"))' "$out")"
      elif [ "$(date +%u)" = 1 ]; then
        post "🟢 homeserver weekly: all clear. $(jq -r '.structured_output.summary' "$out")"
      fi

      # A month of reports is plenty.
      find ${stateDir}/reports -name '*.json' -mtime +30 -delete
    '';
  };
in
{
  users.users.claude-ops = {
    isSystemUser = true;
    group = "claude-ops";
    home = stateDir;
    # journalctl without root.
    extraGroups = [ "systemd-journal" ];
  };
  users.groups.claude-ops = { };

  systemd.services.claude-ops = {
    description = "Daily homeserver health check by Claude Code";
    after = [
      "network-online.target"
      "prometheus.service"
      "loki.service"
      "grafana.service"
    ];
    wants = [ "network-online.target" ];
    environment = {
      HOME = stateDir;
      # No update checks or telemetry from an unattended run.
      DISABLE_AUTOUPDATER = "1";
      CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC = "1";
    };
    serviceConfig = {
      Type = "oneshot";
      User = "claude-ops";
      Group = "claude-ops";
      ExecStart = lib.getExe check;
      WorkingDirectory = stateDir;
      StateDirectory = "claude-ops";
      StateDirectoryMode = "0700";
      # Read as root by systemd, handed over readable only by this unit.
      LoadCredential = [
        "token:${config.age.secrets.claude-ops.path}"
        "discord:${config.age.secrets.grafana-discord.path}"
        "grafana:${config.age.secrets.claude-ops-grafana.path}"
      ];
      TimeoutStartSec = "30min";
      Nice = 10;
      MemoryMax = "2G";

      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictSUIDSGID = true;
      LockPersonality = true;
      RestrictRealtime = true;
      # Not PrivateDevices: `zpool status` needs /dev/zfs.
    };
  };

  systemd.timers.claude-ops = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 07:30";
      # Catch up after a night the box was off.
      Persistent = true;
    };
  };
}
