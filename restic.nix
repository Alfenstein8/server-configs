{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 8002;
  dataDir = "/mnt/storage/data/restic";

  # One password file per repository, named after its directory under dataDir:
  #   /var/lib/restic-server-passwords/backup
  #   /var/lib/restic-server-passwords/laptop-backup
  # Not agenix: these are the clients' own repository passwords, and a missing
  # .age file breaks evaluation of the whole flake. Create them on the server,
  # root-owned and 0400.
  passwordDir = "/var/lib/restic-server-passwords";

  keepOpts = [
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
    # restic-server-prune unit below.
    appendOnly = true;

    # privateRepos = true;
    # ^ Worth having -- it stops the laptop reaching the desktop's repository --
    # but it is a migration, not a flag. Access is only granted when the URL
    # contains a subdirectory matching the login name, so backup/ and
    # laptop-backup/ would have to move under a per-user prefix and every client
    # would need its repository URL changed. Separate commit, with the clients
    # in front of you.
  };

  # Retention for the client repositories, since append-only takes it away from
  # the clients. This works on the files directly rather than through the REST
  # server, so append-only does not block it.
  #
  # Each repository is encrypted with the password its client chose, so pruning
  # one requires a copy of that password here. Repositories without a password
  # file are skipped with a log line rather than failing the unit, and if the
  # directory does not exist at all the unit is skipped entirely -- so this is
  # inert until you populate it.
  systemd.services.restic-server-prune = {
    description = "Prune the restic REST server's client repositories";
    unitConfig.ConditionPathExists = passwordDir;
    path = [ pkgs.restic ];
    serviceConfig = {
      Type = "oneshot";
      # prune rewrites pack files; keep it off the back of the other jobs.
      IOSchedulingClass = "idle";
      Nice = 10;
    };
    script = ''
      shopt -s nullglob
      for repo in ${dataDir}/*; do
        [ -f "$repo/config" ] || continue
        name=$(basename "$repo")
        pw="${passwordDir}/$name"
        if [ ! -f "$pw" ]; then
          echo "no password file at $pw -- skipping $name"
          continue
        fi
        echo "pruning $name"
        restic -r "$repo" -p "$pw" forget --prune ${lib.concatStringsSep " " keepOpts}
      done
    '';
  };

  systemd.timers.restic-server-prune = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 03:00";
      Persistent = true;
      RandomizedDelaySec = "30m";
    };
  };

  shlam.services.restic = {
    inherit port;
    dashboard = {
      title = "Restic";
      group = "File Management";
      order = 40;
      icon = "restic.webp";
      description = "Backup Repository";
    };
  };
}
