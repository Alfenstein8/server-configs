{ config, ... }:
let
  port = 8002;
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
    dataDir = "/mnt/storage/data/restic";

    # The registry gives this a vhost, so the repository is reachable from the
    # public internet behind htpasswd and TLS. Append-only means a client that
    # gets compromised can add snapshots but never delete or rewrite them --
    # ransomware on the laptop encrypts the laptop, not its own backup history.
    #
    # The cost: clients can no longer prune. Retention now runs here instead,
    # against the data directory:
    #   restic -r /mnt/storage/data/restic/<repo> forget --prune --keep-daily 7 ...
    appendOnly = true;

    # privateRepos = true;
    # ^ Worth having -- it stops the laptop reaching the desktop's repository --
    # but it is a migration, not a flag. Access is only granted when the URL
    # contains a subdirectory matching the login name, so backup/ and
    # laptop-backup/ would have to move under a per-user prefix and every client
    # would need its repository URL changed. Separate commit, with the clients
    # in front of you.
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
