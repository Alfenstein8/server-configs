{
  pkgs,
  config,
  lib,
  ...
}:
{
  services.caddy = {
    enable = true;
    globalConfig = "";
    virtualHosts = {
      "http://dawarich.shlambert.top, https://dawarich.shlambert.top".extraConfig = ''
        reverse_proxy localhost:3002
      '';

      "http://netdata.shlambert.top, https://netdata.shlambert.top".extraConfig = ''
        reverse_proxy localhost:19999
      '';

      "http://vpn.shlambert.top, https://vpn.shlambert.top".extraConfig = ''
        reverse_proxy localhost:51821
      '';

      "http://prowlarr.shlambert.top, https://prowlarr.shlambert.top".extraConfig = ''
        reverse_proxy localhost:9696
      '';

      "http://radarr.shlambert.top, https://radarr.shlambert.top".extraConfig = ''
        reverse_proxy localhost:7878
      '';

      "http://sonarr.shlambert.top, https://sonarr.shlambert.top".extraConfig = ''
        reverse_proxy localhost:8989
      '';

      "http://torrent.shlambert.top, https://torrent.shlambert.top".extraConfig = ''
        reverse_proxy localhost:8080
      '';

      "http://bazarr.shlambert.top, https://bazarr.shlambert.top".extraConfig = ''
        reverse_proxy localhost:6767
      '';

    };

  };
}
