{ config, ... }:
let
  port = 4533;
in
{
  services.navidrome = {
    enable = true;
    settings = {
      MusicFolder = "/mnt/storage/data/Shares/Shared/Musik/Music";
      BaseUrl = config.shlam.services.navidrome.url;
      Port = port;
    };
  };
  users.users.navidrome.extraGroups = [ "shared-files" ];

  shlam.services.navidrome.port = port;
}
