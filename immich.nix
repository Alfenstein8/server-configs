{
  services.immich = {
    enable = true;
    mediaLocation = "/mnt/storage/data/immich";
    port = 2283;
    accelerationDevices = null;
    settings = {
      newVersionCheck.enabled = false;
      storageTemplate = {
        enabled = true;
        template = "{{y}}/{{MM}}/{{filename}}";
      };

    };
  };
  users.users.immich.extraGroups = [ "video" "render" "shared-files" "users" "alfred" ];
}
