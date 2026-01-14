{pkgs, ...}:
{
  services.cockpit = {
    enable = true;
    port = 9090;
    allowed-origins = [ "https://cockpit.shlambert.top" ];
  };

  environment.systemPackages = with pkgs; [ cockpit ];

  services.caddy.virtualHosts."https://cockpit.shlambert.top".extraConfig = ''
  reverse_proxy localhost:9090
  '';
}
