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
  "restic-htpasswd.age".publicKeys = [ homeserver ];
  "restic-client-backup.age".publicKeys = [ homeserver ];
  "restic-client-laptop-backup.age".publicKeys = [ homeserver ];
  "freshrss.age".publicKeys = [ homeserver ];
  "headplane.age".publicKeys = [ homeserver ];
  "tailscale-authkey.age".publicKeys = [ homeserver ];
  "qbit-manage.age".publicKeys = [ homeserver ];
  "homepage.age".publicKeys = [ homeserver ];
  # P7 (services/p7.nix)
  "p7.age".publicKeys = [ homeserver ];
  "p7-firebase.age".publicKeys = [ homeserver ];
}
