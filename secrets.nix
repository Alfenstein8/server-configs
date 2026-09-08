{
  age.secrets = {
    spaceship.file = ./secrets/spaceship.age;
    restic.file = ./secrets/restic.age;
    backblaze.file = ./secrets/backblaze.age;
    immich.file = ./secrets/immich.age;
    airvpn.file = ./secrets/airvpn.age;
    wireguard.file = ./secrets/wireguard.age;
    restic-htpasswd = {
      file = ./secrets/restic-htpasswd.age;
      owner = "restic";
    };
    # The laptop's and desktop's own repository passwords, needed here because
    # append-only moved retention off the clients. Owned by restic, because the
    # prune units run as that user so the files they rewrite in the repository
    # keep the same ownership rest-server created them with.
    restic-client-backup = {
      file = ./secrets/restic-client-backup.age;
      owner = "restic";
    };
    restic-client-laptop-backup = {
      file = ./secrets/restic-client-laptop-backup.age;
      owner = "restic";
    };
    grafana = {
      file = ./secrets/grafana.age;
      owner = "grafana";
    };
    freshrss = {
      file = ./secrets/freshrss.age;
      owner = "freshrss";
    };
  };
  age.identityPaths = [ "/root/.ssh/id_ed25519" ];
}
