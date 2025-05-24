{
  services.caddy = {
    enable = true;
    globalConfig = ''
      auto_https off
    '';

    virtualHosts."http://immich.shlambert.top".extraConfig = ''
    reverse_proxy localhost:2283
    '';

    virtualHosts."http://paper.shlambert.top".extraConfig = ''
    reverse_proxy localhost:28981
    '';

    virtualHosts."http://radicale.shlambert.top".extraConfig = ''
    reverse_proxy localhost:5232
    '';

    virtualHosts."http://netdata.shlambert.top".extraConfig = ''
    reverse_proxy localhost:19999
    '';

    virtualHosts."http://uptime.shlambert.top".extraConfig = ''
    reverse_proxy localhost:3001
    '';

    virtualHosts."http://home.shlambert.top".extraConfig = ''
    reverse_proxy localhost:8082
    '';

    virtualHosts."http://vpn.shlambert.top".extraConfig = ''
    reverse_proxy localhost:51821
    '';

    virtualHosts."http://share.shlambert.top".extraConfig = ''
    reverse_proxy localhost:3000
    '';

    virtualHosts."http://jellyfin.shlambert.top".extraConfig = ''
    reverse_proxy localhost:8096
    '';

    virtualHosts."http://prowlarr.shlambert.top".extraConfig = ''
    reverse_proxy localhost:9696
    '';

    virtualHosts."http://radarr.shlambert.top".extraConfig = ''
    reverse_proxy localhost:7878
    '';

    virtualHosts."http://deluge.shlambert.top".extraConfig = ''
    reverse_proxy localhost:8112
    '';
  };
}

