{
  imports = [ ./docker-compose.nix ];
  services.caddy.virtualHosts."http://owntracks.shlambert.top".extraConfig = ''
    reverse_proxy localhost:8083
  '';

  services.caddy.virtualHosts."http://frontend.shlambert.top".extraConfig = ''
    reverse_proxy localhost:8084
  '';
}
