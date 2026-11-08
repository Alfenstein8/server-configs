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
      shared = true;
      order = 10;
      icon = "jellyfin.svg";
      description = "Media Server";
      # version 2 authenticates with the Authorization header rather than the
      # legacy X-Emby-Token one.
      extra.widget = {
        type = "jellyfin";
        url = "http://localhost:${toString port}";
        key = "{{HOMEPAGE_VAR_JELLYFIN_KEY}}";
        version = 2;
        enableBlocks = true;
        enableNowPlaying = true;
      };
    };
  };
}
