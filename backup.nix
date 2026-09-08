{ config, ... }:
let
  # Hetzner Storage Box. `account` is both the SSH username and the hostname
  # label, and is the only value that changes when the box is ordered.
  account = "uXXXXXX";
  host = "${account}.your-storagebox.de";

  # Storage Boxes speak SSH on 23, not 22.
  sshPort = 23;

  # Generated on the server, public half pasted into the Storage Box settings:
  #   ssh-keygen -t ed25519 -N "" -f /root/.ssh/storagebox
  # Deliberately outside the repo: agenix would work, but a missing .age file
  # breaks evaluation of the whole flake, and this key has to exist before the
  # first run either way.
  keyFile = "/root/.ssh/storagebox";
in
{
  services.restic.backups = {
    "storagebox" = {
      paths = [ "/mnt/storage/data" ];
      initialize = true;

      # /home is the account root on a Storage Box, not the server's /home.
      repository = "sftp:${account}@${host}:/home/restic/homeserver";

      passwordFile = config.age.secrets.restic.path;

      # restic's sftp backend shells out to ssh, and the unit runs as root with
      # no ~/.ssh/config -- so the port, the key and the host-key policy have to
      # be passed here. accept-new trusts the box on first contact and pins it
      # afterwards; run one manual `ssh -p 23 ...` first if you would rather
      # verify the fingerprint by hand.
      extraOptions = [
        "sftp.command='ssh ${account}@${host} -p ${toString sshPort} -i ${keyFile} -o StrictHostKeyChecking=accept-new -s sftp'"
      ];

      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };

      exclude = [
        # 4.3 TiB of re-acquirable video. The single reason this fits a 5 TB box.
        "/mnt/storage/data/media"

        # The REST server's own repository (restic.nix). Already encrypted and
        # deduplicated, so restic can neither compress nor dedup it a second
        # time -- it would upload ~95 GiB at full size and grow with every
        # client snapshot. It needs a copy offsite too, but as an rclone mirror
        # of the directory, not nested inside this repository.
        "/mnt/storage/data/restic"

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
}
