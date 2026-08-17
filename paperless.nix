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
    dashboard = {
      title = "Paperless-ngx";
      group = "File Management";
      order = 20;
      icon = "paperless-ngx.svg";
      description = "Document Archiving";
    };
  };
}
