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
              href = "http://jellyfin.shlambert.top";
            };
          }
          {
            "Jellyseerr" = {
              icon = "jellyseerr.svg";
              description = "Media Requests";
              href = "http://jellyseerr.shlambert.top";
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
              href = "http://immich.shlambert.top";
            };
          }
          {
            "Paperless-ngx" = {
              icon = "paperless-ngx.svg";
              description = "Document Archiving";
              href = "http://paper.shlambert.top";
            };
          }
          {
            "Pingvin Share" = {
              icon = "pingvin-share.svg";
              description = "File Sharing";
              href = "http://share.shlambert.top";
            };
          }
          {
            "Syncthing" = {
              icon = "syncthing.svg";
              description = "File Synchronization";
              href = "http://syncthing.shlambert.top";
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
              href = "http://radicale.shlambert.top";
            };
          }
          {
            "Uptime Kuma" = {
              icon = "uptime-kuma.svg";
              description = "Service Monitoring";
              href = "http://uptime.shlambert.top";
            };
          }
          {
            "WG-Easy" = {
              icon = "wg-easy.svg";
              description = "WireGuard VPN Management";
              href = "http://vpn.shlambert.top";
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
              href = "http://radarr.shlambert.top";
            };
          }
          {
            "Sonarr" = {
              icon = "sonarr.svg";
              description = "TV Show Automation";
              href = "http://sonarr.shlambert.top";
            };
          }
          {
            "Bazarr" = {
              icon = "bazarr.svg";
              description = "Subtitle Automation";
              href = "http://bazarr.shlambert.top";
            };
          }
          {
            "Prowlarr" = {
              icon = "prowlarr.svg";
              description = "Indexer Management";
              href = "http://prowlarr.shlambert.top";
            };
          }
          {
            "qBittorrent" = {
              icon = "qbittorrent.svg";
              description = "Torrent Client";
              href = "http://torrent.shlambert.top";
            };
          }

	];
      }
    ];
  };
}
