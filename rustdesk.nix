{
  services.rustdesk-server = {
    enable = true;
    openFirewall = true;
    signal.relayHosts = [
      "192.168.0.188"
      "10.8.0.1"
    ];
  };
}
