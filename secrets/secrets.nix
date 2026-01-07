let
  homeserver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIbSz/PgJO5EEYmyKSuFMZZczqlrfJ/NSXDUritstkN/";
in
{
  "spaceship.age".publicKeys = [ homeserver ];
  "restic.age".publicKeys = [ homeserver ];
  "backblaze.age".publicKeys = [ homeserver ];
  "immich.age".publicKeys = [ homeserver ];
  "mullvad.age".publicKeys = [ homeserver ];
}
