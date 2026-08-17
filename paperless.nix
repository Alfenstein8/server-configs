{ config, ... }:
{
  services.paperless = {
    enable = true;
    port = 28981;
    domain = config.shlam.services.paperless.host;
    dataDir = "/mnt/storage/data/paperless";
  };

  shlam.services.paperless = {
    subdomain = "paper";
    port = config.services.paperless.port;
  };
}
