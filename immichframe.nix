{ config, ... }:
let
  port = 6565;
in
{
  services.immichframe = {
    enable = true;
    inherit port;
    settings = {
      General = {
        Language = "da";
        UnitSystem = "metric";
        ShowAlbumName = false;
        ClockFormat = "HH:mm";
        ClockDateFormat = "eee, d MMM";
      };
      Accounts = [
        {
          ImmichServerUrl = config.shlam.services.immich.url;
          ApiKeyFile = config.age.secrets.immich.path;
          Albums = [ "8fe9c514-8eaf-4ebc-b853-d4ab5f468d8d" ];
        }
      ];
    };
  };

  # No dashboard tile: this is a wall display, not something to click through to.
  shlam.services.immichframe = {
    subdomain = "frame";
    inherit port;
  };
}
