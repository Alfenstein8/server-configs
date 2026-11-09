{
  config,
  lib,
  pkgs,
  ...
}:
let
  port = 3000;
  cfg = config.services.forgejo;

  # Single sign-on through Authelia, whose client is in authelia.nix. Forgejo
  # keeps login sources in its database rather than app.ini, so preStart below
  # creates this one, and updates it whenever these arguments or the secret
  # change. The name is part of the callback URL Authelia allows, so changing
  # it means changing that too.
  oauthName = "Authelia";
  oauthArgs = [
    "--name"
    oauthName
    "--provider"
    "openidConnect"
    "--key"
    "forgejo"
    "--auto-discover-url"
    "${config.shlam.services.auth.url}/.well-known/openid-configuration"
    "--scopes"
    "openid"
    "--scopes"
    "profile"
    "--scopes"
    "email"
    # Authelia has already asked for the second factor.
    "--skip-local-2fa"
  ];
in
{
  # Forgejo only queues workflow jobs; this runner is what executes them, each in
  # a podman container picked by the job's `runs-on` label. Connects by the
  # public URL, not localhost: jobs clone from the same URL, and localhost in a
  # job container is the container. AdGuard's rewrite keeps it on the LAN. It
  # finds podman's socket on its own, and doesn't mount it into the jobs.
  services.forgejo-runner.instances.homeserver = {
    enable = true;
    settings = {
      runner.labels = [
        "ubuntu-latest:docker://node:20-bookworm"
        "ubuntu-22.04:docker://node:20-bullseye"
        "docker:docker://node:20-bookworm"
      ];
      # The runner's UUID, as Site Administration -> Actions -> Runners shows it.
      server.connections.default = {
        url = config.shlam.services.forgejo.url;
        uuid = "477d531d-3b52-49cf-a792-c502ef186c50";
      };
    };
    secrets.server.connections.default.token_url = config.age.secrets.forgejo-runner.path;
  };

  services.forgejo = {
    enable = true;
    stateDir = "/mnt/storage/data/forgejo";
    settings = {
      server = {
        DOMAIN = config.shlam.services.forgejo.host;
        ROOT_URL = config.shlam.services.forgejo.url;
        HTTP_PORT = port;
        SSH_PORT = 2222;
        SSH_LISTEN_PORT = 2222;
        START_SSH_SERVER = true;
      };
      # Closed: the Actions runner below runs any account's workflows on this box.
      # New accounts come from Site Administration -> User Accounts.
      service.DISABLE_REGISTRATION = true;
      # Forgejo's defaults, spelled out because they are what keeps the
      # registration closed for SSO too: a first Authelia login makes no
      # account, it offers to link one -- sign in once with the existing
      # account's password, and from then on the button is enough. Password
      # login, SSH and the Actions runner are unaffected.
      oauth2_client = {
        ENABLE_AUTO_REGISTRATION = false;
        ACCOUNT_LINKING = "login";
      };
      actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "github";
      };
      # /metrics for prometheus.nix, which scrapes it over loopback. No TOKEN:
      # the vhost below refuses the path instead, so it never leaves the box.
      metrics.ENABLED = true;
    };
    lfs.enable = true;
  };

  # After the module's own preStart, which has migrated the database. The stamp
  # holds a hash of the arguments and the secret, so the CLI -- and the secret
  # on its command line -- only runs when one of them has changed.
  #
  # add-oauth/update-oauth fetch the discovery document and refuse to save
  # when Authelia can't be reached. That must not keep Forgejo from starting
  # -- git over SSH and password logins don't need Authelia -- so a failure
  # only warns, leaves the stamp alone, and is retried on the next start.
  systemd.services.forgejo.preStart = lib.mkAfter ''
    fj=${cfg.package}/bin/forgejo
    secretFile=${config.age.secrets.forgejo-oidc.path}
    stamp=${cfg.stateDir}/.oauth-${oauthName}.sha256
    args=(${lib.escapeShellArgs oauthArgs})

    want=$({ printf '%s\n' "''${args[@]}"; cat "$secretFile"; } | sha256sum | cut -d' ' -f1)
    id=$("$fj" admin auth list | ${lib.getExe pkgs.gawk} -v n=${oauthName} '$2 == n { print $1 }')

    if [ -z "$id" ]; then
      cmd=(add-oauth)
    elif [ "$(cat "$stamp" 2>/dev/null)" != "$want" ]; then
      cmd=(update-oauth --id "$id")
    else
      cmd=()
    fi
    if [ ''${#cmd[@]} -gt 0 ]; then
      if "$fj" admin auth "''${cmd[@]}" "''${args[@]}" --secret "$(< "$secretFile")"; then
        echo "$want" > "$stamp"
      else
        echo "warning: could not set up the ${oauthName} login source; retrying on next start" >&2
      fi
    fi
  '';
  # Ordering only, so that a deploy restarting both brings Authelia up first.
  # Not a dependency: Forgejo has to run without it.
  systemd.services.forgejo.after = [
    "authelia-main.service"
    "caddy.service"
  ];

  shlam.services.forgejo = {
    subdomain = "git";
    inherit port;
    # Forgejo's metrics are unauthenticated; they are Prometheus' business only.
    extraConfig = "respond /metrics 404";
    dashboard = {
      title = "Forgejo";
      group = "Infrastructure";
      order = 30;
      icon = "forgejo.svg";
      description = "Git Hosting";
    };
  };
}
