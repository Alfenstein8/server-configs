{
  services.navidrome = {
    enable = true;
    settings = {
      MusicFolder = "/mnt/storage/data/Shares/Shared/Musik/Music";
      BaseUrl = "navidrome.shlambert.top";
    };
  };
  users.users.navidrome.extraGroups = [ "shared-files" ];
  services.caddy.virtualHosts."http://navidrome.shlambert.top".extraConfig = ''
    reverse_proxy localhost:4533
  '';
}
