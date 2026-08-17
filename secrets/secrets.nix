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
  "restic-htpasswd.age".publicKeys = [ homeserver ];
  "freshrss.age".publicKeys = [ homeserver ];
}
