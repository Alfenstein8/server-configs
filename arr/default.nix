{
  imports = [
    ./docker-compose.nix
  ];

  # Ports come from the published mappings in ./docker-compose.nix, which is
  # compose2nix output and gets regenerated -- so they are declared here.
  #
  # prowlarr and qbittorrent share gluetun's network namespace
  # (--network=container:gluetun), so 9696 and 8080 are published by the gluetun
  # container rather than by the services themselves. Caddy still reaches both
  # on localhost.
  shlam.services = {
    radarr = {
      port = 7878;
      dashboard = {
        title = "Radarr";
        group = "Media administration";
        order = 10;
        icon = "radarr.svg";
        description = "Movie Automation";
      };
    };

    sonarr = {
      port = 8989;
      dashboard = {
        title = "Sonarr";
        group = "Media administration";
        order = 20;
        icon = "sonarr.svg";
        description = "TV Show Automation";
      };
    };

    bazarr = {
      port = 6767;
      dashboard = {
        title = "Bazarr";
        group = "Media administration";
        order = 30;
        icon = "bazarr.svg";
        description = "Subtitle Automation";
      };
    };

    prowlarr = {
      port = 9696;
      dashboard = {
        title = "Prowlarr";
        group = "Media administration";
        order = 40;
        icon = "prowlarr.svg";
        description = "Indexer Management";
      };
    };

    qbittorrent = {
      subdomain = "torrent";
      port = 8080;
      dashboard = {
        title = "qBittorrent";
        group = "Media administration";
        order = 50;
        icon = "qbittorrent.svg";
        description = "Torrent Client";
      };
    };

    watcharr = {
      subdomain = "watchlist";
      port = 3080;
      dashboard = {
        title = "Watcharr";
        group = "Media";
        order = 30;
        icon = "watcharr-light.webp";
        description = "Watch list";
      };
    };
  };
}
