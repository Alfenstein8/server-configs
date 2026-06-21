{ pkgs, config, ... }:
{

  networking.firewall.allowedUDPPorts = [ 51820 ];

  networking.wireguard = {
    enable = true;
    interfaces.wg0 = {
      ips = [ "10.8.0.1/24" ];
      listenPort = 51820;

      privateKeyFile = config.age.secrets.wireguard.path;

      postSetup = ''
        ${pkgs.iptables}/bin/iptables -A FORWARD -i wg0 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -o eno1 -j MASQUERADE
      '';
      postShutdown = ''
        ${pkgs.iptables}/bin/iptables -D FORWARD -i wg0 -j ACCEPT
        ${pkgs.iptables}/bin/iptables -t nat -D POSTROUTING -s 10.8.0.0/24 -o eno1 -j MASQUERADE
      '';

      peers = [
        {
          name = "oneplus-phone";
          publicKey = "lVhLVbeGWGZafGhAb6ddgLsspqIT0ZQc1L0pCom+SUY=";
          allowedIPs = [ "10.8.0.2/32" ];
        }
        {
          name = "tux-laptop";
          publicKey = "wL3prq6+hOHqNbSqNUYTkyUEET4yfp1KupzEYnhntjA=";
          allowedIPs = [ "10.8.0.3/32" ];
        }
        {
          name = "zehra-desktop";
          publicKey = "/HcB18CU6+q82Be1F+Sz4dOEcp4VuL+7TJ5NWvkcFRU=";
          allowedIPs = [ "10.8.0.4/32" ];
        }
        {
          name = "zehra-ipad";
          publicKey = "tYyz3mR7DuihQcBMFP8hhUMCVQyLLE1UPkWDv0RcfhU=";
          allowedIPs = [ "10.8.0.5/32" ];
        }
        {
          name = "chromecast";
          publicKey = "DOKwjuT0MMYT0U1liAGPnEYkAk3vb+ptW4wKZpMDaA4=";
          allowedIPs = [ "10.8.0.6/32" ];
        }
      ];
    };
  };
  networking.firewall.interfaces.wg0.allowedUDPPorts = [ 53 ];
  networking.firewall.interfaces.wg0.allowedTCPPorts = [ 53 ];
  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
}
