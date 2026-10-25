# Wishlist (github.com/cmintey/wishlist): shared wish lists where family can
# claim gifts without the list owner seeing who claimed what.
#
# First run: open the URL and go through the setup wizard. Then, in the admin
# panel, switch public signup off (invite only) -- the site is on the internet,
# and by default anyone with the URL can make an account. For guests without an
# account, set a group to Registry mode, which gives the list a public link.
{ config, ... }:
let
  port = 3280;
  dataDir = "/mnt/storage/data/wishlist";
in
{
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";

  virtualisation.oci-containers.containers.wishlist = {
    # Pinned: bump by hand after reading the release notes.
    image = "ghcr.io/cmintey/wishlist:v0.69.0";
    environment = {
      # The app breaks without it; must be the URL people actually open.
      ORIGIN = config.shlam.services.wishlist.url;
      DEFAULT_CURRENCY = "DKK";
      TOKEN_TIME = "72"; # hours an invite / password-reset link stays valid
    };
    volumes = [
      "${dataDir}/data:/usr/src/app/data" # SQLite database
      "${dataDir}/uploads:/usr/src/app/uploads"
    ];
    # Loopback only; Caddy is the way in.
    ports = [ "127.0.0.1:${toString port}:3280" ];
    log-driver = "journald";
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 root root -"
    "d ${dataDir}/data 0750 root root -"
    "d ${dataDir}/uploads 0750 root root -"
  ];

  shlam.services.wishlist = {
    inherit port;

    # Family need it from outside, so it joins zehra.click and hyggr on the
    # router's WAN 443 -> 8443 / WAN 80 -> 8880 forward (see
    # services/quantumsurvivors.nix).
    publicPort = 8443;
    publicHttpPort = 8880;
    dashboard = {
      title = "Wishlist";
      group = "Productivity & Utilities";
      order = 50;
      icon = "mdi-gift";
      description = "Ønskelister";
    };
  };
}
