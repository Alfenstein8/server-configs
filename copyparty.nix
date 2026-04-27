{ pkgs, copyparty, ... }:
{
  # add the copyparty overlay to expose the package to the module
  nixpkgs.overlays = [ copyparty.overlays.default ];
  # (optional) install the package globally
  environment.systemPackages = [ pkgs.copyparty ];
  # configure the copyparty module
  services.copyparty = {
    enable = true;
  };
}
