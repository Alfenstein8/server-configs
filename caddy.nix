{pkgs, config, lib, ...}:
let
  certloc = "/var/lib/acme/shlambert.top";
in
{
  services.caddy = {
    enable = true;
    globalConfig = ''
    '';
    virtualHosts = {
      "http://immich.shlambert.top, https://immich.shlambert.top".extraConfig = ''
      reverse_proxy localhost:2283
      '';

      "http://paper.shlambert.top, https://paper.shlambert.top".extraConfig = ''
      reverse_proxy localhost:28981
      '';

      "radicale.shlambert.top".extraConfig = ''
      reverse_proxy localhost:5232
        tls ${certloc}/cert.pem ${certloc}/key.pem
      '';

      # virtualHosts."radicale.shlambert.top".extraConfig = ''
      # reverse_proxy localhost:5232
      #  tls ${certloc}/cert.pem ${certloc}/key.pem {
      #      protocols tls1.3
      #  }
      # '';

      "http://netdata.shlambert.top, https://netdata.shlambert.top".extraConfig = ''
      reverse_proxy localhost:19999
      '';

      "https://tube.shlambert.top".extraConfig = ''
      reverse_proxy localhost:8000
      '';

      "http://uptime.shlambert.top, https://uptime.shlambert.top".extraConfig = ''
      reverse_proxy localhost:3001
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

      "http://launchpad.shlambert.top, https://launchpad.shlambert.top".extraConfig = ''
      reverse_proxy localhost:5500
      '';

      "https://adguard.shlambert.top".extraConfig = ''
      reverse_proxy localhost:3005
      '';

      "https://watchlist.shlambert.top".extraConfig = ''
      reverse_proxy localhost:3080
      '';

      "https://navidrome.shlambert.top".extraConfig = ''
        reverse_proxy localhost:4533
      '';

      "https://git.shlambert.top".extraConfig = ''
        reverse_proxy localhost:3000
      '';
    };


  };
}

