{ config, ... }:
let
  port = 6565;
in
{
  services.immichframe = {
    enable = true;
    port = port;
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
          ImmichServerUrl = "https://immich.shlambert.top";
          ApiKeyFile = config.age.secrets.immich.path;
          Albums = [ "8fe9c514-8eaf-4ebc-b853-d4ab5f468d8d" ];
        }
      ];
    };
  };

  services.caddy.virtualHosts."http://frame.shlambert.top, https://frame.shlambert.top".extraConfig =
    ''
      reverse_proxy localhost:${toString port}
    '';
}
