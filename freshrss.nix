# Work in progress
{
  services.freshrss = {
    enable = true;
    api.enable = true;
    baseUrl = "https://rss.shlambert.top";
    dataDir = "/mnt/storage/data/freshrss";
    webserver = "caddy";
  };
  services.caddy.virtualHosts."https://rss.shlambert.top".extraConfig = ''
    reverse_proxy localhost:9090
  '';
}
