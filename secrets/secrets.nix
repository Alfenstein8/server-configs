let
  homeserver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIbSz/PgJO5EEYmyKSuFMZZczqlrfJ/NSXDUritstkN/";
in
{
  "spaceship.age".publicKeys = [ homeserver ];
  "restic.age".publicKeys = [ homeserver ];
  "backblaze.age".publicKeys = [ homeserver ];
  "immich.age".publicKeys = [ homeserver ];
  "airvpn.age".publicKeys = [ homeserver ];
  "wireguard.age".publicKeys = [ homeserver ];
  "grafana.age".publicKeys = [ homeserver ];
  "grafana-discord.age".publicKeys = [ homeserver ];
  "ntfy.age".publicKeys = [ homeserver ];
  "ntfy-homeserver.age".publicKeys = [ homeserver ];
  "claude-ops.age".publicKeys = [ homeserver ];
  "claude-ops-grafana.age".publicKeys = [ homeserver ];
  "restic-htpasswd.age".publicKeys = [ homeserver ];
  "restic-client-backup.age".publicKeys = [ homeserver ];
  "restic-client-laptop-backup.age".publicKeys = [ homeserver ];
  "freshrss.age".publicKeys = [ homeserver ];
  "headplane.age".publicKeys = [ homeserver ];
  "tailscale-authkey.age".publicKeys = [ homeserver ];
  "qbit-manage.age".publicKeys = [ homeserver ];
  "homepage.age".publicKeys = [ homeserver ];
  "forgejo-runner.age".publicKeys = [ homeserver ];
  "radicale-users.age".publicKeys = [ homeserver ];
  "adguardhome-password.age".publicKeys = [ homeserver ];
  "storagebox-ssh.age".publicKeys = [ homeserver ];
  "samba-shares.age".publicKeys = [ homeserver ];
  # Hyggr (services/hyggr.nix)
  "hyggr.age".publicKeys = [ homeserver ];
  "hyggr-firebase.age".publicKeys = [ homeserver ];
  "hyggr-google-services.age".publicKeys = [ homeserver ];
  "hyggr-smtp-user.age".publicKeys = [ homeserver ];
}
