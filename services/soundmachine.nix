{ config, pkgs, ... }:
let
  port = 4173;
  stateDir = "/var/lib/soundmachine";

  # The checkout, built by hand (`pnpm install && pnpm build`). The service only
  # reads it: the app's data lives in stateDir.
  src = "/home/alfred/manual/soundmachine/server";

  # The app keeps local.db and uploads/ relative to its working directory, which
  # used to be the checkout. Copied over once, on the first start with an empty
  # stateDir; the originals stay where they were, as a backup.
  migrate = pkgs.writeShellScript "soundmachine-migrate" ''
    set -eu
    [ -e ${stateDir}/local.db ] && exit 0
    [ -e ${src}/local.db ] && cp -a ${src}/local.db ${stateDir}/
    [ -d ${src}/uploads ] && cp -a ${src}/uploads ${stateDir}/
    chown -R soundmachine:soundmachine ${stateDir}
  '';
in
{
  users.users.soundmachine = {
    isSystemUser = true;
    group = "soundmachine";
    home = stateDir;
  };
  users.groups.soundmachine = { };

  systemd.services.soundmachine = {
    description = "Soundmachine Server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    # ffmpeg is spawned from PATH for transcoding uploads.
    path = [
      pkgs.nodejs
      pkgs.ffmpeg
    ];

    environment = {
      # adapter-node's settings. Loopback only: Caddy is the way in.
      HOST = "127.0.0.1";
      PORT = toString port;
      ORIGIN = config.shlam.services.soundmachine.url;
      # Absolute, so it doesn't depend on the working directory. The app's .env
      # is not read by the built server.
      DATABASE_URL = "${stateDir}/local.db";
      # adapter-node caps request bodies at 512 KB, which would refuse most
      # sample uploads; `vite preview`, which this replaces, had no cap.
      BODY_SIZE_LIMIT = "Infinity";
      HOME = stateDir;
    };

    serviceConfig = {
      Type = "simple";
      User = "soundmachine";
      Group = "soundmachine";
      StateDirectory = "soundmachine";
      StateDirectoryMode = "0700";
      # Where ./uploads resolves.
      WorkingDirectory = stateDir;
      # "+": as root, outside the sandbox, so it can read the checkout's data.
      ExecStartPre = "+${migrate}";
      # The adapter-node build `pnpm build` writes, instead of `vite preview`
      # (a dev tool, which also wants to write into the checkout).
      ExecStart = "${pkgs.nodejs}/bin/node ${src}/build/index.js";
      Restart = "on-failure";
      RestartSec = "5s";

      # /home is an empty tmpfs apart from the checkout, mounted read-only: the
      # service sees nothing else of alfred's home, and the rest of the
      # filesystem is read-only apart from stateDir.
      ProtectHome = "tmpfs";
      BindReadOnlyPaths = [ src ];
      ProtectSystem = "strict";
      PrivateTmp = true;
      PrivateDevices = true;
      NoNewPrivileges = true;
      CapabilityBoundingSet = "";
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectKernelLogs = true;
      ProtectControlGroups = true;
      ProtectClock = true;
      ProtectHostname = true;
      RestrictSUIDSGID = true;
      RestrictRealtime = true;
      RestrictNamespaces = true;
      LockPersonality = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
      ];
      # Not MemoryDenyWriteExecute: Node's JIT needs writable+executable memory.
    };
  };

  shlam.services.soundmachine = {
    subdomain = "launchpad";
    inherit port;
    dashboard = {
      title = "Launchpad";
      group = "Productivity & Utilities";
      shared = true;
      order = 50;
      icon = "mdi-music-box";
      description = "Soundmachine";
    };
  };
}
