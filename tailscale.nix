# Redundant with ./headscale.nix, which already sets services.tailscale.enable
# together with useRoutingFeatures.
{
  services.tailscale.enable = true;
}
