{
  services.immich = {
    enable = true;
    mediaLocation = "/mnt/storage/data/immich";
    port = 2283;
    accelerationDevices = null;
  };
  users.users.immich.extraGroups = [ "video" "render" "shared-files" "users" ];
}
