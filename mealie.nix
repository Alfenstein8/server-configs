{
  services.mealie = {
    enable = true;
    port = 8001;
  };

  services.caddy.virtualHosts."https://menu.shlambert.top".extraConfig = ''
    reverse_proxy localhost:8001
  '';
}
