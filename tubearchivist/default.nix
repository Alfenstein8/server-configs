{
  imports = [
    ./docker-compose.nix
  ];

  # The container publishes 8000:8000. Declared here rather than read from
  # ./docker-compose.nix, which is compose2nix-generated and gets regenerated.
  shlam.services.tubearchivist = {
    subdomain = "tube";
    port = 8000;
  };
}
