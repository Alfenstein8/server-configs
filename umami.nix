{ config, ... }:
{
  # Cookieless, self-hosted web analytics for alfredmakne.dk.
  #
  # Only the dashboard gets a vhost here, at stats.shlambert.top, which like every
  # other *.shlambert.top host is LAN/tailnet only. Visitors never talk to this
  # host: the site's own Caddy block (services.portfolio-site, from the CV flake)
  # proxies just one path, alfredmakne.dk/stats/api/send, to Umami's /api/send on
  # localhost. The rest of Umami, its login and its API, stays off the internet.
  #
  # First start: log in as admin / umami and change the password straight away,
  # then add the site (Settings -> Websites -> Add website, domain
  # alfredmakne.dk). Its website ID goes to services.portfolio-site.umami.websiteId.
  services.umami = {
    enable = true;
    # Creates the `umami` database and role on the existing PostgreSQL, reached
    # over the unix socket with peer auth: no database password to keep. The
    # nightly pg_dumpall in backup.nix picks the database up on its own.
    createPostgresqlDatabase = true;
    settings = {
      # 3000 is Forgejo's, 3001 uptime-kuma's, 3010 Grafana's.
      PORT = 3030;
      HOSTNAME = "127.0.0.1";
      APP_SECRET_FILE = config.age.secrets.umami.path;
      DISABLE_TELEMETRY = true;
    };
  };

  # Signs dashboard sessions: a random string, alone in the file. Read by systemd
  # (LoadCredential) as root, so owned by root -- umami runs as a DynamicUser.
  age.secrets.umami.file = ./secrets/umami.age;

  shlam.services.umami = {
    subdomain = "stats";
    port = config.services.umami.settings.PORT;
    dashboard = {
      title = "Umami";
      group = "Infrastructure";
      order = 15;
      icon = "umami.svg";
      description = "Web analytics";
    };
  };
}
