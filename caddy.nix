{
  # Virtual hosts are not defined here any more. Each service declares its own
  # with shlam.services.<name> in its own module (see ./registry.nix), so that
  # commenting a module out of ./configuration.nix also removes its route --
  # which is what the dawarich, netdata and vpn entries deleted here failed to
  # do, leaving three hostnames serving 502s.
  services.caddy.enable = true;
}
