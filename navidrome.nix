{
  services.navidrome = {
    enable = true;
    settings = {
      MusicFolder = "/mnt/storage/data/Shares/Shared/Musik/Music";
      BaseUrl = "https://navidrome.shlambert.top";
    };
  };
  users.users.navidrome.extraGroups = [ "shared-files" ];
}
