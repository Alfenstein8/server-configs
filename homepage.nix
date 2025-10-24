{
  services.homepage-dashboard = {
    enable = true;
    allowedHosts = "home.shlambert.top";
    services = [
      {
        "Media" = [
          {
            "Jellyfin" = {
              icon = "jellyfin.svg"; # Assuming default icons are available or you'll provide them
              description = "Media Server";
              href = "https://jellyfin.shlambert.top";
            };
          }
          {
            "Jellyseerr" = {
              icon = "jellyseerr.svg";
              description = "Media Requests";
              href = "https://jellyseerr.shlambert.top";
            };
          }
          {
            "Watcharr" = {
              icon = "watcharr-light.webp";
              description = "Watch list";
              href = "https://watchlist.shlambert.top";
            };
          }
        ];
      }
      {
        "File Management" = [
          {
            "Immich" = {
              icon = "immich.svg";
              description = "Photo & Video Backup";
              href = "https://immich.shlambert.top";
            };
          }
          {
            "Paperless-ngx" = {
              icon = "paperless-ngx.svg";
              description = "Document Archiving";
              href = "https://paper.shlambert.top";
            };
          }
          {
            "Pingvin Share" = {
              icon = "pingvin-share.svg";
              description = "File Sharing";
              href = "https://share.shlambert.top";
            };
          }
          {
            "Syncthing" = {
              icon = "syncthing.svg";
              description = "File Synchronization";
              href = "https://syncthing.shlambert.top";
            };
          }
        ];
      }
      {
        "Productivity & Utilities" = [
          {
            "Radicale" = {
              icon = "radicale.svg";
              description = "Calendar & Contacts";
              href = "https://radicale.shlambert.top";
            };
          }
          {
            "Uptime Kuma" = {
              icon = "uptime-kuma.svg";
              description = "Service Monitoring";
              href = "https://uptime.shlambert.top";
            };
          }
          {
            "WG-Easy" = {
              icon = "wireguard.svg";
              description = "WireGuard VPN Management";
              href = "https://vpn.shlambert.top";
            };
          }
        ];
      }
      {
        "Media administration" = [
          {
            "Radarr" = {
              icon = "radarr.svg";
              description = "Movie Automation";
              href = "https://radarr.shlambert.top";
            };
          }
          {
            "Sonarr" = {
              icon = "sonarr.svg";
              description = "TV Show Automation";
              href = "https://sonarr.shlambert.top";
            };
          }
          {
            "Bazarr" = {
              icon = "bazarr.svg";
              description = "Subtitle Automation";
              href = "https://bazarr.shlambert.top";
            };
          }
          {
            "Prowlarr" = {
              icon = "prowlarr.svg";
              description = "Indexer Management";
              href = "https://prowlarr.shlambert.top";
            };
          }
          {
            "qBittorrent" = {
              icon = "qbittorrent.svg";
              description = "Torrent Client";
              href = "https://torrent.shlambert.top";
            };
          }

        ];
      }
    ];
  };
}
