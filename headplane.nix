{ config, ... }:
let
  # The next free port after headscale's 3006. Loopback-bound, so the vhost is
  # the only way in: the UI inherits Caddy's TLS, and it stays off the internet
  # by the same rule as everything else -- no publicPort, no forward. That
  # matters more here than elsewhere, because a session on this page can hand
  # out pre-auth keys for the whole tailnet.
  port = 3007;
in
{
  services.headplane = {
    enable = true;

    settings.server = {
      host = "127.0.0.1";
      inherit port;

      # Deliberately without the /admin the app actually lives under: headplane
      # compiles that prefix in and appends it itself, so spelling it here puts
      # it into generated links twice.
      base_url = config.shlam.services.headplane.url;

      # Exactly 32 characters, or headplane refuses to start; the module
      # asserts the path is at least set. Owned by headscale's user in
      # ./secrets.nix because that is who this unit runs as -- the module
      # borrows headscale's user and group rather than making its own.
      cookie_secret_path = config.age.secrets.headplane.path;
    };

    # Nothing else needs saying. The module derives the rest from
    # ./headscale.nix: the API endpoint (loopback :3006, not the public name --
    # a call that never leaves the box has no reason to go out through Caddy
    # and the router), the public_url the UI displays (server_url, :8444 and
    # all), and config_path. That last one resolves to a nix store path, so
    # headscale's settings render read-only in the UI -- which is the honest
    # answer here, since the file is generated from ./headscale.nix and
    # anything the UI managed to write would be gone on the next rebuild.
  };

  shlam.services.headplane = {
    inherit port;

    # Bare / serves nothing -- the app is mounted under /admin. One redirect
    # beats having to remember that on a phone.
    extraConfig = ''
      redir / /admin
    '';

    dashboard = {
      title = "Headplane";
      group = "Infrastructure";
      order = 61;
      icon = "headscale.svg";
      description = "Tailnet Admin UI";
    };
  };
}
