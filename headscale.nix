{
  services.headscale = {
    enable = true;
    address = "0.0.0.0";
    port = 3006;
    settings = {
      dns = {
        base_domain = "ts.shlambert.top";
        nameservers.global = [ "192.168.0.188" ];
        extra_records = [
          {
            name = "immich.shlambert.top";
            type = "A";
            value = "100.64.0.2";
          }

        ];
      };
      server_url = "https://headscale.shlambert.top";
      logtail.enabled = false;
    };
  };
  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  services.caddy.virtualHosts."https://headscale.shlambert.top".extraConfig = ''
    reverse_proxy localhost:3006
  '';
}
