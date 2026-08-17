# Parked: not imported from ./configuration.nix. No registry entry -- the signal
# and relay servers speak RustDesk's own protocol, not HTTP.
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
