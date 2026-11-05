# Single sign-on: Authelia at auth.shlambert.top, as an OpenID Connect provider
# and as Caddy's forward_auth backend.
#
# forward_auth is for services with no login worth keeping: set
# shlam.services.<name>.sso.forward = true in the service's module, and the
# registry puts the vhost behind Authelia while the rules below are generated
# from the same entries.
#
# Apps that speak OIDC get a client below, and the app's own module points at
# this one. Each client has two secrets: the app holds the plaintext (in its own
# agenix file), Authelia holds only a PBKDF2 digest of it. Generate a pair with
#
#   authelia crypto hash generate pbkdf2 --random --random.length 64 --random.charset alphanumeric
#
# (nixpkgs#authelia), which prints both.
#
# Users live in authelia-users.age, an Authelia users file:
#
#   users:
#     <username>:
#       displayname: <name>
#       email: <email>
#       password: <digest from `authelia crypto hash generate argon2`>
#       groups: [admins]
#
# It is read-only under /run/agenix, so password reset is switched off. Adding a
# user or changing a password is `agenix -e secrets/authelia-users.age` and a
# rebuild; Authelia reads the file only at startup (watch = false).
#
# Second factors (TOTP, passkeys) are registered at auth.shlambert.top after the
# first password login. Registering asks for a one-time code that Authelia would
# email; with no SMTP set up it is written to the notifier file instead:
#
#   sudo cat /var/lib/authelia-main/notifications.txt
#
# Those registrations live in the SQLite database next to it, so losing
# /var/lib/authelia-main means everyone registers their second factor again.
{ config, lib, ... }:
let
  instance = "main"; # -> authelia-main.service, user authelia-main
  user = "authelia-${instance}";
  stateDir = "/var/lib/${user}";
  port = 9091;

  # Root-owned: the module hands these to the unit with LoadCredential.
  credential = name: { file = ./secrets/${name}.age; };
  # Read by Authelia itself, from the users file path or a {{ secret }} template.
  ownedSecret = name: {
    file = ./secrets/${name}.age;
    owner = user;
  };

  # {{ secret }} is Authelia's template filter, which the module switches on
  # because the issuer key is set. It reads the file when Authelia starts, so the
  # digest stays out of the store.
  secretRef = name: ''{{ secret "${config.age.secrets.${name}.path}" }}'';

  forwardSvcs = lib.filterAttrs (_: s: s.vhost && s.sso.forward) config.shlam.services;
  forwardHosts = lib.mapAttrsToList (_: s: s.host) forwardSvcs;

  # This box's LAN address, as in adguardhome.nix. If the two drift apart the
  # probes merely see the login redirect again; nobody is let in by it.
  lanIP = "192.168.0.188";
in
{
  age.secrets = {
    authelia-jwt = credential "authelia-jwt";
    authelia-session = credential "authelia-session";
    authelia-storage = credential "authelia-storage";
    authelia-oidc-hmac = credential "authelia-oidc-hmac";
    # RSA private key (PEM) that signs the ID tokens.
    authelia-oidc-issuer = credential "authelia-oidc-issuer";
    authelia-users = ownedSecret "authelia-users";
    # Grafana's client secret, as Authelia's PBKDF2 digest; the plaintext is
    # grafana-oidc.age (see grafana.nix).
    authelia-grafana-digest = ownedSecret "authelia-grafana-digest";
  };

  services.authelia.instances.${instance} = {
    enable = true;
    secrets = with config.age.secrets; {
      jwtSecretFile = authelia-jwt.path;
      sessionSecretFile = authelia-session.path;
      storageEncryptionKeyFile = authelia-storage.path;
      oidcHmacSecretFile = authelia-oidc-hmac.path;
      oidcIssuerPrivateKeyFile = authelia-oidc-issuer.path;
    };
    settings = {
      theme = "auto";
      server.address = "tcp://127.0.0.1:${toString port}/";
      log.level = "info"; # the module's default is debug

      authentication_backend = {
        password_reset.disable = true;
        file = {
          path = config.age.secrets.authelia-users.path;
          watch = false;
        };
      };

      # forward_auth's rules, one per shlam.services entry with sso.forward set
      # (see ../registry.nix). Rules are matched top to bottom, first match wins.
      access_control = {
        # Authelia refuses `deny` while there are no rules, which is the case
        # whenever no service has opted in.
        default_policy = if forwardHosts == [ ] then "two_factor" else "deny";
        rules = lib.optionals (forwardHosts != [ ]) (
          [
            {
              # The box itself, which is where the blackbox probes come from:
              # without this they would see the 302 to the login page and call
              # the service up whether it is or not. Nothing on the box gains
              # access by it -- it can reach every backend on localhost
              # anyway. Caddy ignores a client's own X-Forwarded-For (no
              # trusted_proxies), so the address cannot be spoofed.
              domain = forwardHosts;
              networks = [ "${lanIP}/32" ];
              policy = "bypass";
            }
          ]
          ++ lib.mapAttrsToList (_: s: {
            domain = s.host;
            subject = map (g: "group:${g}") s.sso.groups;
            policy = "two_factor";
          }) forwardSvcs
        );
      };

      session.cookies = [
        {
          domain = "shlambert.top";
          authelia_url = config.shlam.services.auth.url;
        }
      ];

      storage.local.path = "${stateDir}/db.sqlite3";
      notifier.filesystem.filename = "${stateDir}/notifications.txt";
      totp.issuer = "shlambert.top";

      # Since 4.39 the ID token carries almost no claims; the rest are only at
      # the userinfo endpoint. Grafana evaluates role_attribute_path against the
      # ID token first and stops at any non-empty answer, so without `groups`
      # there it lands on the expression's 'Viewer' fallback and never looks at
      # userinfo. A claims policy puts them back in the token.
      identity_providers.oidc.claims_policies.grafana.id_token = [
        "email"
        "name"
        "groups"
        "preferred_username"
      ];

      identity_providers.oidc.clients = [
        {
          client_id = "grafana";
          client_name = "Grafana";
          claims_policy = "grafana";
          client_secret = secretRef "authelia-grafana-digest";
          authorization_policy = "two_factor";
          require_pkce = true;
          pkce_challenge_method = "S256";
          redirect_uris = [ "${config.shlam.services.grafana.url}/login/generic_oauth" ];
          scopes = [
            "openid"
            "profile"
            "email"
            "groups"
          ];
          response_types = [ "code" ];
          grant_types = [ "authorization_code" ];
          userinfo_signed_response_alg = "none";
          token_endpoint_auth_method = "client_secret_basic";
        }
      ];
    };
  };

  shlam.services.auth = {
    inherit port;
    dashboard = {
      title = "Authelia";
      group = "Infrastructure";
      order = 15;
      icon = "authelia.svg";
      description = "Single Sign-On";
    };
  };
}
