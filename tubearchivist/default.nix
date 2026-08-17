{
  imports = [
    ./docker-compose.nix
  ];

  # The container publishes 8000:8000. Declared here rather than read from
  # ./docker-compose.nix, where it only exists inside a "8000:8000/tcp" string.
  shlam.services.tubearchivist = {
    subdomain = "tube";
    port = 8000;
    dashboard = {
      title = "TubeArchivist";
      group = "Media";
      order = 50;
      icon = "tube-archivist.webp";
      description = "YouTube Archive";
    };
  };
}
