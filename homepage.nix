{ config, ... }:
let
  port = 8082;
in
{
  # The service list is generated from shlam.services.<name>.dashboard by
  # ./registry.nix -- each service carries its own tile. Do not add a services
  # list here: the option merges by concatenation, so a second list would show
  # up as duplicate groups rather than as an error.
  services.homepage-dashboard = {
    enable = true;
    listenPort = port;
    allowedHosts = config.shlam.services.homepage.host;
  };

  # No dashboard entry -- the dashboard should not link to itself.
  shlam.services.homepage = {
    subdomain = "home";
    inherit port;
  };
}
