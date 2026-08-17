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
    # privateRepos = true;
  };

  shlam.services.restic.port = port;
}
