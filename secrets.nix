{
  age.secrets = {
    spaceship.file = ./secrets/spaceship.age;
    restic.file = ./secrets/restic.age;
    backblaze.file = ./secrets/backblaze.age;
    immich.file = ./secrets/immich.age;
    mullvad.file = ./secrets/mullvad.age;
    airvpn.file = ./secrets/airvpn.age;
    wireguard.file = ./secrets/wireguard.age;
    tandoor.file = ./secrets/tandoor.age;
    restic-htpasswd = {
      file = ./secrets/restic-htpasswd.age;
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
