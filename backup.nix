# Parked: not imported from ./configuration.nix. No registry entry -- restic
# backups are a systemd timer with no listening port and nothing to proxy.
{ config, ... }:
{
  services.restic.backups = {
    # You can give your backup a meaningful name
    "backblaze" = {
      # The paths you want to back up
      paths = [ "/mnt/storage/data" ];
      initialize = true;

      # The Restic repository URL for Backblaze B2
      # Replace 'your-bucket-name' with your actual B2 bucket name
      repository = "b2:ShlambertBackup";

      # The password for your Restic repository.
      # It's highly recommended to store this securely, e.g., using agenix or sops-nix.
      passwordFile = config.age.secrets.restic.path;

      # Schedule for backups using systemd.timers syntax.
      # This example runs daily at 3 AM.
      timerConfig = {
        OnCalendar = "daily";
        Persistent = true;
      };

      exclude = [ "/mnt/storage/data/media" ];

      # Pruning old backups based on a retention policy.
      # This example keeps:
      # - 7 daily backups
      # - 4 weekly backups
      # - 12 monthly backups
      # - 1 yearly backup
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 4"
        "--keep-monthly 12"
        "--keep-yearly 1"
      ];

      environmentFile = config.age.secrets.backblaze.path;

      # You might want to enable health checking with healthchecks.io or similar.
      # healthChecks = [ "https://hc-ping.com/YOUR_HEALTHCHECK_UUID" ];
    };
  };
}
