{ config, lib, ... }:
let
  # The headscale API key Headplane needs for OIDC logins (an API-key login
  # brings its own). Minted by the unit itself on first start, below, rather
  # than kept in agenix: it only exists on this box anyway, and the unit runs as
  # headscale's user, which may talk to headscale's socket.
  #
  # To replace it -- expired, or revoked with `headscale apikeys expire` --
  # delete the file and restart headplane.
  apiKeyFile = "/var/lib/headplane/headscale-api-key";
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

    settings.headscale.api_key_path = apiKeyFile;

    # Single sign-on through Authelia, whose client (authelia.nix) lets in only
    # the `admins` group. The first account to log in this way becomes
    # Headplane's owner; later ones start with no rights until the owner gives
    # them some under Users.
    #
    # API-key login stays as the way in when Authelia is down. It is no weaker
    # than SSO: it takes a headscale API key, which only root on this box can
    # make.
    settings.oidc = {
      issuer = config.shlam.services.auth.url;
      client_id = "headplane";
      client_secret_path = config.age.secrets.headplane-oidc.path;
      # Headplane's default is off; Authelia's client requires it.
      use_pkce = true;
      token_endpoint_auth_method = "client_secret_basic";
      scope = "openid email profile";
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

  # headscale.service is up before this runs (the module orders headplane after
  # it), but its socket can appear a moment later, so wait for it briefly.
  # 3650d because headscale's default is 90d, after which OIDC logins would
  # stop until someone noticed.
  systemd.services.headplane.preStart = ''
    if [ ! -s ${apiKeyFile} ]; then
      for _ in $(seq 30); do
        [ -S ${config.services.headscale.settings.unix_socket} ] && break
        sleep 1
      done
      umask 077
      ${lib.getExe config.services.headscale.package} apikeys create --expiration 3650d \
        > ${apiKeyFile}.tmp
      mv ${apiKeyFile}.tmp ${apiKeyFile}
    fi
  '';

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
