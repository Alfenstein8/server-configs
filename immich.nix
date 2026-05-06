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
  users.users.immich.extraGroups = [
    "video"
    "render"
    "shared-files"
    "users"
    "alfred"
  ];
}
