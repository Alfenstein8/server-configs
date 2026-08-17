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
    bazarr.port = 6767;
    prowlarr.port = 9696;
    radarr.port = 7878;
    sonarr.port = 8989;

    qbittorrent = {
      subdomain = "torrent";
      port = 8080;
    };

    watcharr = {
      subdomain = "watchlist";
      port = 3080;
    };
  };
}
