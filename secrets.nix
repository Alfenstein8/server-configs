{
  age.secrets = {
    spaceship.file = ./secrets/spaceship.age;
    restic.file = ./secrets/restic.age;
    backblaze.file = ./secrets/backblaze.age;
    immich.file = ./secrets/immich.age;
  };
  age.identityPaths = [ "/root/.ssh/id_ed25519" ];
}
