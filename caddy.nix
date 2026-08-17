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
      "http://paper.shlambert.top, https://paper.shlambert.top".extraConfig = ''
        reverse_proxy localhost:28981
      '';

      "http://dawarich.shlambert.top, https://dawarich.shlambert.top".extraConfig = ''
        reverse_proxy localhost:3002
      '';

      "http://netdata.shlambert.top, https://netdata.shlambert.top".extraConfig = ''
        reverse_proxy localhost:19999
      '';

      "http://home.shlambert.top, https://home.shlambert.top".extraConfig = ''
        reverse_proxy localhost:8082
      '';

      "http://vpn.shlambert.top, https://vpn.shlambert.top".extraConfig = ''
        reverse_proxy localhost:51821
      '';

      "http://jellyfin.shlambert.top, https://jellyfin.shlambert.top".extraConfig = ''
        reverse_proxy localhost:8096
      '';

      # virtualHosts."http://jellyfin.shlambert.top".extraConfig = ''
      # reverse_proxy localhost:8096
      # # '';

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

      "http://jellyseerr.shlambert.top, https://jellyseerr.shlambert.top".extraConfig = ''
        reverse_proxy localhost:5055
      '';

      "http://bazarr.shlambert.top, https://bazarr.shlambert.top".extraConfig = ''
        reverse_proxy localhost:6767
      '';

      "http://syncthing.shlambert.top, https://syncthing.shlambert.top".extraConfig = ''
        reverse_proxy localhost:8384
      '';

    };

  };
}
