{ config, pkgs, ... }:
let
  # Hetzner Storage Box BX21. `account` is both the SSH username and the
  # hostname label.
  account = "uXXXXXX";
  host = "${account}.your-storagebox.de";

  # Storage Boxes speak SSH on 23, not 22.
  sshPort = 23;

  # Generated on the server, public half registered with the box:
  #   ssh-keygen -t ed25519 -N "" -f /root/.ssh/storagebox
  # Then one manual connection as root, which verifies the fingerprint against
  # the one in the Hetzner console and writes /root/.ssh/known_hosts. Both jobs
  # below need that entry -- neither trusts a key on first sight:
  #   ssh -p 23 -i /root/.ssh/storagebox uXXXXXX@uXXXXXX.your-storagebox.de
  # Deliberately outside the repo: agenix would work, but a missing .age file
  # breaks evaluation of the whole flake, and this key has to exist before the
  # first run either way.
  keyFile = "/root/.ssh/storagebox";
  knownHosts = "/root/.ssh/known_hosts";

  # /home is the account root on a Storage Box, not the server's /home.
  boxRoot = "/home/restic";

  # Read, not repeated: restic.nix owns this path.
  resticServerDir = config.services.restic.server.dataDir;

  # A running database cannot be backed up as files. restic walks the tree while
  # postgres is still writing to it, so the pages it captures come from
  # different moments and the result may simply not restore. The supported
  # answer is to dump first and back the dump up instead.
  #
  # The dumps land inside /mnt/storage/data, which is already a backup path, so
  # they ride along in the same snapshot rather than needing a second job. They
  # are written uncompressed on purpose: restic deduplicates and compresses in
  # the repository itself, and a plain SQL dump is nearly identical from one
  # night to the next, so it dedups down to almost nothing. Pre-compressing here
  # would make every nightly dump a fresh blob and upload it in full.
  dbDumpDir = "/mnt/storage/data/db-dumps";

  # Jellyfin's SQLite databases. Globbed rather than named below, so the 12.0
  # schema reshuffle cannot silently drop one from the backup.
  jellyfinData = "${config.services.jellyfin.dataDir}/data";
in
{
  services.restic.backups = {
    "storagebox" = {
      paths = [
        "/mnt/storage/data"

        # Jellyfin's state: users, watch history, playlists, plugin config. The
        # media itself is excluded below and re-acquirable; this is not.
        "/var/lib/jellyfin"
      ];
      initialize = true;

      repository = "sftp:${account}@${host}:${boxRoot}/homeserver";

      passwordFile = config.age.secrets.restic.path;

      # restic's sftp backend shells out to ssh, and the unit runs as root with
      # no ~/.ssh/config -- so the port and the key have to be passed here.
      extraOptions = [
        "sftp.command='ssh ${account}@${host} -p ${toString sshPort} -i ${keyFile} -s sftp'"
      ];

      # Runs as root in the unit's preStart, and the module hands it to
      # writeScript -- a standalone executable, so it needs its own shebang.
      # A non-zero exit here fails the unit, which is what we want: a snapshot
      # taken after a failed dump would look healthy and restore nothing.
      backupPrepareCommand = ''
        #!${pkgs.runtimeShell}
        set -euo pipefail

        install -d -m 0700 ${dbDumpDir}

        # pg_dumpall rather than pg_dump: it carries roles and grants too, so a
        # restore does not need immich's database user recreated by hand.
        # Written to .tmp and moved into place, so a dump that dies halfway
        # cannot leave a truncated file that still looks like a backup.
        ${pkgs.util-linux}/bin/runuser -u ${config.services.postgresql.superUser} -- \
          ${config.services.postgresql.package}/bin/pg_dumpall --clean --if-exists \
          > ${dbDumpDir}/postgresql.sql.tmp
        mv ${dbDumpDir}/postgresql.sql.tmp ${dbDumpDir}/postgresql.sql

        # SQLite has the same torn-copy problem as postgres. `.backup` takes a
        # consistent snapshot through the sqlite API while jellyfin keeps
        # running. /var/lib/jellyfin is backed up as files as well, so a miss
        # here is a degraded backup rather than no backup -- hence a warning
        # rather than the hard failure postgres gets.
        install -d -m 0700 ${dbDumpDir}/jellyfin
        shopt -s nullglob
        found=0
        for db in ${jellyfinData}/*.db; do
          found=1
          ${pkgs.sqlite}/bin/sqlite3 "$db" ".backup '${dbDumpDir}/jellyfin/$(basename "$db")'"
        done
        if [ "$found" -eq 0 ]; then
          echo "warning: no *.db under ${jellyfinData}; has jellyfin moved its state?" >&2
        fi
      '';

      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };

      exclude = [
        # 4.3 TiB of re-acquirable video. The single reason this fits a 5 TB box.
        "/mnt/storage/data/media"

        # The REST server's own repository. Already encrypted and deduplicated,
        # so restic can neither compress nor dedup it a second time -- it would
        # upload ~95 GiB at full size and grow with every client snapshot. It
        # goes offsite as a mirror instead, see storagebox-mirror below.
        resticServerDir

        # Regenerated from library/ and upload/ on demand.
        "/mnt/storage/data/immich/thumbs"
        "/mnt/storage/data/immich/encoded-video"

        # Jellyfin's own throwaway data. The live .db files are deliberately
        # NOT excluded: the consistent copies under db-dumps/jellyfin are the
        # ones to restore from, but keeping the originals too means a change in
        # jellyfin's layout cannot leave the snapshot with no database at all.
        "/var/lib/jellyfin/log"
        "/var/lib/jellyfin/transcodes"
      ];

      # Pruning old backups based on a retention policy:
      # 7 daily, 4 weekly, 12 monthly, 1 yearly.
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
        "--keep-yearly 1"
      ];

      # You might want to enable health checking with healthchecks.io or similar.
      # healthChecks = [ "https://hc-ping.com/YOUR_HEALTHCHECK_UUID" ];
    };
  };

  # The laptop and desktop repositories, excluded above, reaching the same box
  # the only way that makes sense for already-encrypted data: a byte-for-byte
  # copy of the directory. No second encryption, no lost deduplication.
  #
  # `sync` propagates deletions -- that is what makes this a mirror rather than
  # an ever-growing pile, and it is also its one weakness: a client that wiped
  # its own history would see the wipe copied here. The Storage Box's snapshots
  # (20 on BX21) are the answer, because they are taken on the box, out of reach
  # of this server and of any client.
  systemd.services.storagebox-mirror = {
    description = "Mirror the restic REST repositories to the Storage Box";
    unitConfig.ConditionPathExists = keyFile;
    path = [ pkgs.rclone ];
    serviceConfig = {
      Type = "oneshot";
      IOSchedulingClass = "idle";
      Nice = 10;
    };
    script = ''
      rclone sync ${resticServerDir} :sftp:${boxRoot}/pc-repos \
        --config /dev/null \
        --sftp-host=${host} \
        --sftp-user=${account} \
        --sftp-port=${toString sshPort} \
        --sftp-key-file=${keyFile} \
        --sftp-known-hosts-file=${knownHosts} \
        --transfers=8 \
        --stats=0
    '';
  };

  systemd.timers.storagebox-mirror = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # After the nightly restic run, and after Sunday's server-side prune, so
      # the mirror copies a repository that has already been compacted.
      OnCalendar = "*-*-* 04:00:00";
      Persistent = true;
      RandomizedDelaySec = "20m";
    };
  };
}
