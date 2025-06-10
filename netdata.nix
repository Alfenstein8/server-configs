{
  services.netdata = {
    enable = true;

    config = {
      global = {
        "memory mode" = "ram";
        "debug log" = "none";
        "access log" = "none";
        "error log" = "syslog";
      };
    };
  };
  services.caddy.virtualHosts."http://netdata.shlambert.top".extraConfig = ''
  reverse_proxy localhost:19999
  '';
  networking.firewall.allowedTCPPorts = [19999];
}
