let
  homeserver = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIbSz/PgJO5EEYmyKSuFMZZczqlrfJ/NSXDUritstkN/";
in
{
  "secret1.age".publicKeys = [ homeserver ];
}
