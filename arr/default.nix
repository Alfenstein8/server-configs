{
  imports = [
    ./docker-compose.nix
  ];

  # Ports come from the published mappings in ./docker-compose.nix, which is
  # compose2nix output and gets regenerated -- so they are declared here.
  shlam.services.watcharr = {
    subdomain = "watchlist";
    port = 3080;
  };
}
