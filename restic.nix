{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 8002;
  dataDir = "/mnt/storage/data/restic";

  # Directory under dataDir -> the password that repository was created with.
  # Declared rather than discovered: adding a third machine is a new .age file
  # and a line here, which is a better trade than a glob that silently does
  # nothing when a password is missing.
  clientRepos = {
    "backup" = config.age.secrets.restic-client-backup.path;
    "laptop-backup" = config.age.secrets.restic-client-laptop-backup.path;
  };

  keepOpts = lib.concatStringsSep " " [
    "--keep-daily 7"
    "--keep-weekly 4"
    "--keep-monthly 12"
    "--keep-yearly 1"
  ];
in
{
  services.restic.server = {
    enable = true;
    htpasswd-file = config.age.secrets.restic-htpasswd.path;
    # listenAddress is a bare port string here, not host:port. The module feeds
    # it to systemd as ListenStream=, which accepts that and binds all
    # interfaces -- so it works, but lib.toInt on it would be fragile if it ever
    # gained a host part. Hence the let binding.
    listenAddress = toString port;
    inherit dataDir;

    # The registry gives this a vhost, so the repository is reachable from the
    # public internet behind htpasswd and TLS. Append-only means a client that
    # gets compromised can add snapshots but never delete or rewrite them --
    # ransomware on the laptop encrypts the laptop, not its own backup history.
    #
    # The cost is that clients can no longer prune, so retention moves to the
    # restic-prune-* units below.
    appendOnly = true;

    # Bytes and blobs written, read and deleted per repository, for the Apps
    # dashboard -- a backup that suddenly uploads ten times its usual size
    # shows up there. Without --prometheus-no-auth Prometheus would need an
    # htpasswd login of its own; the vhost refuses /metrics instead (below).
    prometheus = true;
    extraFlags = [ "--prometheus-no-auth" ];

    # privateRepos = true;
    # ^ Worth having -- it stops the laptop reaching the desktop's repository --
    # but it is a migration, not a flag. Access is only granted when the URL
    # contains a subdirectory matching the login name, so backup/ and
    # laptop-backup/ would have to move under a per-user prefix and every client
    # would need its repository URL changed. Separate commit, with the clients
    # in front of you.
  };

  # Retention for the client repositories, since append-only takes it away from
  # the clients. These work on the files directly rather than through the REST
  # server, so append-only does not block them.
  #
  # One unit per repository, so a stale lock on the laptop's repo cannot stop
  # the desktop's from being pruned, and `systemctl status restic-prune-backup`
  # names the one that failed.
  systemd.services = lib.mapAttrs' (
    name: passwordFile:
    lib.nameValuePair "restic-prune-${name}" {
      description = "Prune the ${name} restic repository";
      path = [ pkgs.restic ];

      environment = {
        RESTIC_REPOSITORY = "${dataDir}/${name}";
        RESTIC_PASSWORD_FILE = passwordFile;
        # A systemd unit has no $HOME, and restic refuses to start without
        # somewhere to put its cache. Same shape the upstream restic module
        # uses: systemd owns the directory, restic is told where it landed.
        RESTIC_CACHE_DIR = "/var/cache/restic-prune-${name}";
      };

      serviceConfig = {
        Type = "oneshot";
        # Same user rest-server runs as. prune rewrites pack files in place of
        # old ones, and doing that as root would leave root-owned files in a
        # repository every other writer touches as `restic`.
        User = "restic";
        Group = "restic";
        CacheDirectory = "restic-prune-${name}";
        CacheDirectoryMode = "0700";
        # prune rewrites pack files; keep it off the back of everything else.
        IOSchedulingClass = "idle";
        Nice = 10;
      };

      script = ''
        # A client that crashes mid-backup leaves its lock behind, and every
        # later prune fails on it. `unlock` removes only locks restic considers
        # stale -- older than 30 minutes -- and a running restic refreshes its
        # own lock every few minutes, so a backup that is genuinely in progress
        # is never a candidate.
        restic unlock

        # If a client really is backing up right now, wait for it instead of
        # giving up until next Sunday. Type=oneshot has no start timeout.
        #
        # --group-by host matches what the clients used to pass themselves. The
        # default is host,paths, which silently starts a fresh retention group
        # the day someone edits the path list in their backup unit -- and then
        # keeps 7 dailies of the old set forever.
        restic forget --prune --retry-lock 1h --group-by host ${keepOpts}
      '';
    }
  ) clientRepos;

  systemd.timers = lib.mapAttrs' (
    name: _:
    lib.nameValuePair "restic-prune-${name}" {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "Sun 03:00";
        Persistent = true;
        # Staggers the repos so they do not rewrite pack files at once.
        RandomizedDelaySec = "30m";
      };
    }
  ) clientRepos;

  shlam.services.restic = {
    inherit port;
    # Unauthenticated (see above), so Prometheus' business only.
    extraConfig = "respond /metrics 404";
    dashboard = {
      title = "Restic";
      group = "File Management";
      order = 40;
      icon = "restic.webp";
      description = "Backup Repository";
    };
  };
}
