{pkgs, ...}:
{
  services.cockpit = {
    enable = true;
    port = 9090;
    allowed-origins = [ "http://cockpit.shlambert.top" ];
    settings = {
      WebService = {
        AllowUnencrypted = true;
      };
    };
  };

  environment.systemPackages = with pkgs; [ cockpit ];

  services.caddy.virtualHosts."http://cockpit.shlambert.top".extraConfig = ''
  reverse_proxy localhost:9090
  '';
}
