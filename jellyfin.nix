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
    # The apps on phones and TVs keep the server address they were set up with,
    # and log in with an Authorization header -- which HTTP clients drop when a
    # redirect crosses to another domain, so Jellyfin answers 400. Watcharr,
    # which logs in through Jellyfin, broke the same way. Serve the old name
    # directly until every client has been pointed at the new one.
    oldHostMode = "serve";
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
