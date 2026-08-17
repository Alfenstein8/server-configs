{
  pkgs,
  config,
  lib,
  ...
}:
{
  services.caddy = {
    enable = true;
    globalConfig = "";
    virtualHosts = {
      "http://dawarich.shlambert.top, https://dawarich.shlambert.top".extraConfig = ''
        reverse_proxy localhost:3002
      '';

      "http://netdata.shlambert.top, https://netdata.shlambert.top".extraConfig = ''
        reverse_proxy localhost:19999
      '';

      "http://vpn.shlambert.top, https://vpn.shlambert.top".extraConfig = ''
        reverse_proxy localhost:51821
      '';

    };

  };
}
