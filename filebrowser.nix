{
  services.filebrowser = {
    enable = true;
    port = 8085;
  };

  services.caddy.virtualHosts."http://filebrowser.shlambert.top".extraConfig = ''
    reverse_proxy localhost:8384
    '';
}
