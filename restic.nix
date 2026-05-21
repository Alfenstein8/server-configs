{ config, ... }:
{
  services.restic.server = {
    enable = true;
    htpasswd-file = config.age.secrets.restic-htpasswd.path;
    listenAddress = "8002";
    dataDir = "/mnt/storage/data/restic";
    # privateRepos = true;
  };

  services.caddy.virtualHosts."https://restic.shlambert.top".extraConfig = ''
    reverse_proxy localhost:8002
  '';
}
