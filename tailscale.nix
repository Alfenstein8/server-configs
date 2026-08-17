# Parked: not imported from ./configuration.nix, and redundant while it stays
# that way -- ./headscale.nix already sets services.tailscale.enable together
# with useRoutingFeatures. No registry entry: the daemon serves no web UI.
{
  services.tailscale.enable = true;
}
