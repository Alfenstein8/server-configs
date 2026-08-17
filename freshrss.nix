{ config, ... }:
# Release feeds for the services in this repo live in ./freshrss-feeds.opml.
# Import them from the web UI (Subscription management > Import / export)
{
  services.freshrss = {
    enable = true;
    api.enable = true;
    baseUrl = config.shlam.services.freshrss.url;
    dataDir = "/mnt/storage/data/freshrss";
    # FreshRSS is PHP, not a daemon on a port: the module runs it as a php-fpm
    # pool and makes Caddy serve it over a unix socket, so no reverse_proxy.
    webserver = "caddy";
    virtualHost = config.shlam.services.freshrss.host;
    defaultUser = "alfred";
    passwordFile = config.age.secrets.freshrss.path;
  };

  # Deliberately no port. That leaves upstream null, so proxy is false and the
  # registry emits only useACMEHost -- the freshrss module supplies the site
  # body (root / php_fastcgi / file_server) and the two merge on the same
  # vhost. A reverse_proxy here would shadow PHP entirely.
  shlam.services.freshrss = {
    subdomain = "rss";
    dashboard = {
      title = "FreshRSS";
      group = "Productivity & Utilities";
      order = 30;
      icon = "freshrss.svg";
      description = "RSS Reader";
    };
  };
}
