{ config, pkgs, ... }:
let
  # Hetzner Storage Box. `account` is both the SSH username and the hostname
  # label, and is the only value that changes when the box is ordered.
  account = "uXXXXXX";
  host = "${account}.your-storagebox.de";

  # Storage Boxes speak SSH on 23, not 22.
  sshPort = 23;

  # Generated on the server, public half pasted into the Storage Box settings:
  #   ssh-keygen -t ed25519 -N "" -f /root/.ssh/storagebox
  # Then one manual connection as root, which verifies the fingerprint and
  # writes /root/.ssh/known_hosts -- both jobs below rely on it being there:
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
in
{
  services.restic.backups = {
    "storagebox" = {
      paths = [ "/mnt/storage/data" ];
      initialize = true;

      repository = "sftp:${account}@${host}:${boxRoot}/homeserver";

      passwordFile = config.age.secrets.restic.path;

      # restic's sftp backend shells out to ssh, and the unit runs as root with
      # no ~/.ssh/config -- so the port and the key have to be passed here.
      extraOptions = [
        "sftp.command='ssh ${account}@${host} -p ${toString sshPort} -i ${keyFile} -s sftp'"
      ];

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
