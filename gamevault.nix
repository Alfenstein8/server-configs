# GameVault (gamevau.lt, github.com/Phalcode/gamevault-backend): a self-hosted
# library for PC games, at games.shlambert.top.
#
# The server also serves the GameVault 2 client as a web UI on the same port:
# browse the library and download games there. Installing and launching games
# needs the GameVault desktop app; point it at the same URL.
#
# One container. Its database is the host's PostgreSQL, the one Immich already
# uses, reached over the Unix socket with peer authentication: the container
# runs as the `gamevault` user below, so PostgreSQL sees that user and lets it in
# as the `gamevault` role, with no password to manage. backup.nix's nightly
# pg_dumpall then covers it too.
#
# Where things live:
#
#   /mnt/storage/data/gamevault/files      the games, one archive or folder per
#                                          game, named e.g.
#                                          "Stray (2022).7z" or
#                                          "HITMAN 3 (v3.10.1) (2021).zip"
#                                          (GameVault's docs, "File and Folder
#                                          Structure"). Not backed up: big and
#                                          can be re-acquired, like media/
#   /mnt/storage/data/gamevault/media      covers, avatars and other images
#   /mnt/storage/data/gamevault/savefiles  cloud saves from the desktop app
#   /mnt/storage/data/gamevault/config     the cached web UI, optional
#                                          config.yaml and news.md
#
# First run: log in through Authelia before anyone else does. GameVault makes
# the first account an admin, and SSO creates that account. Everyone after that
# is an ordinary user, already activated, because Authelia decides who has an
# account at all. Username and password sign-up is off. The password login
# itself stays on, but an SSO account has a random password, so to use it as a
# way in while Authelia is down, set one under the profile's settings.
#
# Metadata: covers and descriptions come from IGDB, which needs a Twitch
# developer app. Add METADATA_IGDB_CLIENT_ID=... and
# METADATA_IGDB_CLIENT_SECRET=... to secrets/gamevault.age (the same pair RomM
# uses works) and restart podman-gamevault. Without them GameVault indexes the
# games but finds no metadata.
{ config, ... }:
let
  port = 8091;
  dataDir = "/mnt/storage/data/gamevault";

  # Fixed, because the container needs it as a number (PUID/PGID) and peer
  # authentication needs it to be this user's. Above the range NixOS hands out
  # to system users (below 1000) and far above the normal users here.
  uid = 2500;

  pgSocketDir = "/run/postgresql";
  authUrl = config.shlam.services.auth.url;
in
{
  # Edit with: ageGen secrets/gamevault.age. An env file read by podman as root,
  # so root-owned.
  #
  #   AUTH_SEED                  random; signs GameVault's tokens
  #   AUTH_OAUTH2_CLIENT_SECRET  the plaintext half of authelia-gamevault-digest.age
  #   METADATA_IGDB_CLIENT_ID, METADATA_IGDB_CLIENT_SECRET  (optional, see above)
  age.secrets.gamevault.file = ./secrets/gamevault.age;

  users.users.gamevault = {
    isSystemUser = true;
    inherit uid;
    group = "gamevault";
  };
  users.groups.gamevault.gid = uid;

  services.postgresql = {
    ensureDatabases = [ "gamevault" ];
    ensureUsers = [
      {
        name = "gamevault";
        ensureDBOwnership = true;
      }
    ];
  };

  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers.gamevault = {
    # Pinned: bump by hand after reading the release notes.
    image = "docker.io/phalcode/gamevault-backend:17.2.0";
    environment = {
      # The entrypoint starts as root, takes the data folders over for this
      # uid and then drops to it.
      PUID = toString uid;
      PGID = toString uid;
      TZ = config.time.timeZone;

      DB_SYSTEM = "POSTGRESQL";
      # A directory as the host means a Unix socket to node-postgres.
      DB_HOST = pgSocketDir;
      DB_USERNAME = "gamevault";
      DB_DATABASE = "gamevault";

      # The journal has the logs already.
      SERVER_LOG_FILES_ENABLED = "false";
      SERVER_REGISTRATION_DISABLED = "true";
      SERVER_ACCOUNT_ACTIVATION_DISABLED = "true";
      ANALYTICS_ENABLED = "false";

      SAVEFILES_ENABLED = "true";

      # Authelia. GameVault sends no PKCE challenge and puts the client secret
      # in the token request body, which is what the client in authelia.nix
      # expects. Users are matched by preferred_username or email, read from
      # the verified ID token and the userinfo endpoint.
      AUTH_OAUTH2_ENABLED = "true";
      AUTH_OAUTH2_CLIENT_ID = "gamevault";
      AUTH_OAUTH2_AUTH_URL = "${authUrl}/api/oidc/authorization";
      AUTH_OAUTH2_TOKEN_URL = "${authUrl}/api/oidc/token";
      AUTH_OAUTH2_USERINFO_URL = "${authUrl}/api/oidc/userinfo";
      AUTH_OAUTH2_ISSUER_URL = authUrl;
      AUTH_OAUTH2_VERIFY_ID_TOKEN = "true";
      AUTH_OAUTH2_CALLBACK_URL = "${config.shlam.services.gamevault.url}/api/auth/oauth2/login";
    };
    environmentFiles = [ config.age.secrets.gamevault.path ];
    volumes = [
      "${dataDir}/files:/files"
      "${dataDir}/media:/media"
      "${dataDir}/savefiles:/savefiles"
      "${dataDir}/config:/config"
      "${pgSocketDir}:${pgSocketDir}"
    ];
    # Loopback only; Caddy is the way in.
    ports = [ "127.0.0.1:${toString port}:8080" ];
    log-driver = "journald";
  };

  # The database and its role have to exist before the first start, and
  # postgresql.target includes the setup unit that creates them.
  systemd.services.podman-gamevault = {
    requires = [ "postgresql.target" ];
    after = [ "postgresql.target" ];
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 gamevault gamevault -"
    "d ${dataDir}/files 0750 gamevault gamevault -"
    "d ${dataDir}/media 0750 gamevault gamevault -"
    "d ${dataDir}/savefiles 0750 gamevault gamevault -"
    "d ${dataDir}/config 0750 gamevault gamevault -"
  ];

  services.restic.backups.storagebox.exclude = [ "${dataDir}/files" ];

  shlam.services.gamevault = {
    subdomain = "games";
    inherit port;
    dashboard = {
      title = "GameVault";
      group = "Media";
      shared = true;
      order = 75;
      icon = "gamevault.png";
      description = "PC games";
    };
  };
}
