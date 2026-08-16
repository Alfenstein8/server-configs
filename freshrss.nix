{ config, ... }:
# Release feeds for the services in this repo live in ./freshrss-feeds.opml.
# Import them from the web UI (Subscription management > Import / export)
{
  services.freshrss = {
    enable = true;
    api.enable = true;
    baseUrl = "https://rss.shlambert.top";
    dataDir = "/mnt/storage/data/freshrss";
    # FreshRSS is PHP, not a daemon on a port: the module runs it as a php-fpm
    # pool and makes Caddy serve it over a unix socket, so no reverse_proxy.
    webserver = "caddy";
    virtualHost = "https://rss.shlambert.top";
    defaultUser = "alfred";
    passwordFile = config.age.secrets.freshrss.path;
  };
}
