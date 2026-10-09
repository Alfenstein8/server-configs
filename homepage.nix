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
    # Widget credentials -- see the homepage entry in ./secrets.nix.
    environmentFiles = [ config.age.secrets.homepage.path ];

    # The info bar along the top. The unit is ProtectSystem=strict, which makes
    # the filesystem read-only but leaves it visible, so statfs on the pool
    # still works.
    widgets = [
      {
        resources = {
          cpu = true;
          memory = true;
          cputemp = true;
          uptime = true;
        };
      }
      {
        resources = {
          label = "System";
          disk = "/";
        };
      }
      {
        resources = {
          label = "Storage";
          disk = "/mnt/storage";
        };
      }
      {
        datetime = {
          text_size = "xl";
          format = {
            dateStyle = "long";
            timeStyle = "short";
            hourCycle = "h23";
          };
        };
      }
    ];
  };

  # No dashboard entry -- the dashboard should not link to itself.
  shlam.services.homepage = {
    subdomain = "home";
    inherit port;
  };
}
