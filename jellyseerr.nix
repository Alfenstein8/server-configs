{ config, ... }:
{
  services.seerr = {
    enable = true;
    port = 5055;
  };

  shlam.services.jellyseerr.port = config.services.seerr.port;
}
