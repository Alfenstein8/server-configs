{ config, ... }:
{
  services.immich = {
    enable = true;
    mediaLocation = "/mnt/storage/data/immich";
    port = 2283;
    accelerationDevices = null;
    environment = {
      IMMICH_TELEMETRY_INCLUDE = "all";
      IMMICH_API_METRICS_PORT = "8083";
      IMMICH_MICROSERVICES_METRICS_PORT = "8084";
    };
    settings = {
      newVersionCheck.enabled = false;
      storageTemplate = {
        enabled = true;
        template = "{{y}}/{{MM}}/{{filename}}";
      };
    };
  };
  shlam.services.immich = {
    port = config.services.immich.port;
    dashboard = {
      title = "Immich";
      group = "File Management";
      order = 10;
      icon = "immich.svg";
      description = "Photo & Video Backup";
      # version 2 is the API from immich 1.118 on. The key must belong to an
      # admin: the server statistics endpoint is admin-only.
      extra.widget = {
        type = "immich";
        url = "http://localhost:${toString config.services.immich.port}";
        key = "{{HOMEPAGE_VAR_IMMICH_KEY}}";
        version = 2;
      };
    };
  };

  users.users.immich.extraGroups = [
    "video"
    "render"
    "shared-files"
    "users"
    "alfred"
  ];
}
