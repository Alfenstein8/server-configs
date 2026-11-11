# RomM (github.com/rommapp/romm): ROM library manager with in-browser
# emulation (EmulatorJS), at emu.shlambert.top.
#
# Two containers on their own Podman network: RomM itself (it bundles its own
# Valkey for background jobs) and MariaDB, the database RomM is built and tested
# against.
#
# Where things live:
#
#   /mnt/storage/data/romm/library    the ROMs: one folder per platform, e.g.
#                                     library/roms/gba/*.gba (see RomM's docs,
#                                     "Folder structure")
#   /mnt/storage/data/romm/assets     uploaded saves and save states
#   /mnt/storage/data/romm/config     optional config.yml
#   /var/lib/romm/resources           covers and screenshots -- fetched again by
#                                     a rescan, so not backed up
#   /var/lib/romm/{mysql,redis}       live database files, not backed up as
#                                     files; romm-db-dump writes the SQL dump
#                                     the backup takes instead
#
# First run: the first start migrates the database and can take a while -- leave
# it alone until `journalctl -u podman-romm` settles. Then open the URL and go
# through the setup wizard; the account made there is the admin. Give it the
# same email address as your Authelia account, so "Login with Authelia" links to
# it rather than creating a second account.
#
# Single sign-on: anyone with an Authelia account can log in, and is created as
# an ordinary user on first login. Role mapping is deliberately off: with
# OIDC_CLAIM_ROLES set, RomM rejects every user whose groups match none of the
# mapped roles.
#
# Metadata: Hasheous needs no account. IGDB, ScreenScraper, RetroAchievements and
# SteamGridDB need keys; add them to secrets/romm.age as IGDB_CLIENT_ID=...,
# IGDB_CLIENT_SECRET=..., SCREENSCRAPER_USER=..., SCREENSCRAPER_PASSWORD=...,
# RETROACHIEVEMENTS_API_KEY=..., STEAMGRIDDB_API_KEY=... and restart podman-romm.
{ config, pkgs, ... }:
let
  port = 8090;
  dataDir = "/mnt/storage/data/romm";
  stateDir = "/var/lib/romm";
  network = "romm";
  rommUid = "1000";

  # Inside /mnt/storage/data, so the nightly snapshot carries it; next to the
  # PostgreSQL dump backup.nix writes. A literal there too.
  dumpDir = "/mnt/storage/data/db-dumps";
in
{
  # Edit with: ageGen secrets/romm.age (and romm-db.age). Env files read by
  # podman as root, so root-owned.
  #
  # romm.age:     ROMM_AUTH_SECRET_KEY, DB_PASSWD, OIDC_CLIENT_SECRET (the
  #               plaintext half of authelia-romm-digest.age), and any
  #               metadata keys (above)
  # romm-db.age:  MARIADB_PASSWORD (= DB_PASSWD), MARIADB_ROOT_PASSWORD
  #
  # Split so the app container never sees the database root password.
  age.secrets.romm.file = ./secrets/romm.age;
  age.secrets.romm-db.file = ./secrets/romm-db.age;

  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  systemd.services."podman-network-${network}" = {
    path = [ pkgs.podman ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStop = "podman network rm -f ${network}";
    };
    script = ''
      podman network inspect ${network} || podman network create ${network}
    '';
    before = [
      "podman-romm-db.service"
      "podman-romm.service"
    ];
    requiredBy = [
      "podman-romm-db.service"
      "podman-romm.service"
    ];
  };

  virtualisation.oci-containers.containers.romm-db = {
    # The current LTS line. Pinned to it rather than `latest`, so a new major
    # never upgrades the data files on its own.
    image = "docker.io/library/mariadb:11.8";
    environment = {
      MARIADB_DATABASE = "romm";
      MARIADB_USER = "romm";
      # Runs mariadb-upgrade when a newer 11.8 starts on older data files.
      MARIADB_AUTO_UPGRADE = "1";
    };
    environmentFiles = [ config.age.secrets.romm-db.path ];
    volumes = [ "${stateDir}/mysql:/var/lib/mysql" ];
    log-driver = "journald";
    extraOptions = [
      "--network=${network}"
      "--network-alias=romm-db"
    ];
  };

  virtualisation.oci-containers.containers.romm = {
    # Pinned: bump by hand after reading the release notes.
    image = "docker.io/rommapp/romm:5.4.1";
    dependsOn = [ "romm-db" ];
    environment = {
      ROMM_BASE_URL = config.shlam.services.romm.url;
      ROMM_SESSION_SECURE_COOKIE = "true";

      DB_HOST = "romm-db";
      DB_NAME = "romm";
      DB_USER = "romm";

      HASHEOUS_API_ENABLED = "true";

      OIDC_ENABLED = "true";
      OIDC_PROVIDER = "authelia";
      OIDC_CLIENT_ID = "romm";
      OIDC_REDIRECT_URI = "${config.shlam.services.romm.url}/api/oauth/openid";
      OIDC_SERVER_APPLICATION_URL = config.shlam.services.auth.url;
      # Username and password login stays on: the setup wizard's admin is a
      # local account, and it is the way in if Authelia is down.
    };
    environmentFiles = [ config.age.secrets.romm.path ];
    volumes = [
      "${dataDir}/library:/romm/library"
      "${dataDir}/assets:/romm/assets"
      "${dataDir}/config:/romm/config"
      "${stateDir}/resources:/romm/resources"
      "${stateDir}/redis:/redis-data"
    ];
    # Loopback only; Caddy is the way in.
    ports = [ "127.0.0.1:${toString port}:8080" ];
    log-driver = "journald";
    extraOptions = [ "--network=${network}" ];
  };

  # The container runs as root, but its nginx serves ROMs, saves and covers as
  # the image's `romm` user, uid 1000, so it must be able to read them. With
  # root-only folders the scan (root) worked while every download failed with
  # "Permission denied". A numeric uid, because it is the image's user, not
  # one of ours.
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 ${rommUid} ${rommUid} -"
    "d ${dataDir}/library 0750 ${rommUid} ${rommUid} -"
    "d ${dataDir}/assets 0750 ${rommUid} ${rommUid} -"
    "d ${dataDir}/config 0750 ${rommUid} ${rommUid} -"
    "d ${stateDir} 0755 root root -"
    "d ${stateDir}/resources 0750 ${rommUid} ${rommUid} -"
    "d ${stateDir}/redis 0750 root root -"
    # MariaDB's entrypoint chowns this to its own mysql user on first start.
    "d ${stateDir}/mysql 0750 root root -"
  ];

  # The database as SQL, written just before the nightly restic run picks up
  # dumpDir -- the same reasoning as the PostgreSQL dump in backup.nix: live
  # database files copied mid-write may not restore.
  #
  # Wanted, not required, by the backup: a stopped RomM should not hold back
  # the snapshot of everything else. A failed dump fails this unit, which the
  # failed-unit alert reports.
  systemd.services.romm-db-dump = {
    description = "Dump RomM's MariaDB database for the nightly backup";
    path = [ pkgs.podman ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -euo pipefail
      install -d -m 0700 ${dumpDir}
      podman exec romm-db sh -c \
        'exec mariadb-dump --single-transaction -uroot -p"$MARIADB_ROOT_PASSWORD" romm' \
        > ${dumpDir}/romm.sql.tmp
      mv ${dumpDir}/romm.sql.tmp ${dumpDir}/romm.sql
    '';
  };
  systemd.services.restic-backups-storagebox = {
    wants = [ "romm-db-dump.service" ];
    after = [ "romm-db-dump.service" ];
  };

  shlam.services.romm = {
    subdomain = "emu";
    inherit port;
    dashboard = {
      title = "RomM";
      group = "Media";
      shared = true;
      order = 70;
      icon = "romm.svg";
      description = "Retro games";
    };
  };
}
