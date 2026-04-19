{
  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 3006;
    settings = {
      dns = {
        base_domain = "ts.shlambert.top";
        nameservers.global = [ "127.0.0.1" ];
      };
      server_url = "https://headscale.shlambert.top";
      logtail.enabled = false;
    };
  };

  services.caddy.virtualHosts."https://headscale.shlambert.top".extraConfig = ''
    reverse_proxy localhost:3006
  '';
}
