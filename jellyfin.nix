{ pkgs, ... }:
let
  # The NixOS module exposes no port option; 8096 is Jellyfin's own default.
  port = 8096;
in
{
  services.jellyfin = {
    enable = true;
    openFirewall = true;
  };
  environment.systemPackages = [
    pkgs.jellyfin
    pkgs.jellyfin-web
    pkgs.jellyfin-ffmpeg
  ];
  users.users.jellyfin = {
    extraGroups = [
      "render"
      "video"
    ];
  };

  shlam.services.jellyfin = {
    inherit port;
    dashboard = {
      title = "Jellyfin";
      group = "Media";
      order = 10;
      icon = "jellyfin.svg";
      description = "Media Server";
    };
  };
}
