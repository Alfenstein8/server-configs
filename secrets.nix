{
  age.secrets = {
    spaceship.file = ./secrets/spaceship.age;
    restic.file = ./secrets/restic.age;
    backblaze.file = ./secrets/backblaze.age;
    immich.file = ./secrets/immich.age;
    # Immich's OIDC client secret, alone in the file; the digest half is
    # authelia-immich-digest.age (see authelia.nix). Root-owned: the immich
    # module reads it with LoadCredential.
    immich-oidc.file = ./secrets/immich-oidc.age;
    airvpn.file = ./secrets/airvpn.age;
    wireguard.file = ./secrets/wireguard.age;
    restic-htpasswd = {
      file = ./secrets/restic-htpasswd.age;
      owner = "restic";
    };
    # The laptop's and desktop's own repository passwords, needed here because
    # append-only moved retention off the clients. Owned by restic, because the
    # prune units run as that user so the files they rewrite in the repository
    # keep the same ownership rest-server created them with.
    restic-client-backup = {
      file = ./secrets/restic-client-backup.age;
      owner = "restic";
    };
    restic-client-laptop-backup = {
      file = ./secrets/restic-client-laptop-backup.age;
      owner = "restic";
    };
    grafana = {
      file = ./secrets/grafana.age;
      owner = "grafana";
    };
    # Grafana's OIDC client secret for Authelia, alone in the file. Authelia
    # holds its digest in authelia-grafana-digest.age (see authelia.nix).
    grafana-oidc = {
      file = ./secrets/grafana-oidc.age;
      owner = "grafana";
    };
    # ntfy's users, ACLs and tokens, as an environment file (see ntfy.nix).
    # Read by systemd as root, so owned by root -- ntfy runs as a DynamicUser.
    ntfy.file = ./secrets/ntfy.age;
    # The `homeserver` account's ntfy token, for everything that sends alerts
    # (Grafana, claude-ops): NTFY_TOKEN=tk_..., the same token as in ntfy.age's
    # NTFY_AUTH_TOKENS. Read by systemd as root, so owned by root.
    ntfy-homeserver.file = ./secrets/ntfy-homeserver.age;
    # The daily Claude Code check (claude-ops/): a long-lived token from
    # `claude setup-token`, alone in the file. Read by systemd as root and
    # passed to the unit with LoadCredential, so owned by root.
    claude-ops.file = ./secrets/claude-ops.age;
    # Its read-only Grafana access: a service-account token with the Viewer
    # role, alone in the file. Root-owned for the same reason.
    claude-ops-grafana.file = ./secrets/claude-ops-grafana.age;
    freshrss = {
      file = ./secrets/freshrss.age;
      owner = "freshrss";
    };
    # Headplane's session cookie key -- exactly 32 characters. Owned by
    # headscale because headplane's module runs the service as headscale's user
    # rather than creating one of its own.
    headplane = {
      file = ./secrets/headplane.age;
      owner = "headscale";
    };
    # Headplane's OIDC client secret, the plaintext half of the pair whose
    # digest is authelia-headplane-digest.age (see authelia.nix). Owned by
    # headscale for the same reason as the cookie key above.
    headplane-oidc = {
      file = ./secrets/headplane-oidc.age;
      owner = "headscale";
    };
    # A reusable headscale pre-auth key, so tailscaled-autoconnect can register
    # this box again on its own. Left owned by root, which is who that unit
    # runs as. Create it with `headscale preauthkeys create` -- note the CLI
    # default expiry is one hour, so pass --expiration explicitly, and
    # --reusable, or it is spent on the first registration.
    tailscale-authkey.file = ./secrets/tailscale-authkey.age;
    # qbit-manage's qBittorrent WebUI login, as an environment file:
    # QBIT_PASS=<password>. Read by systemd as root, so owned by root.
    qbit-manage.file = ./secrets/qbit-manage.age;
    # API keys and logins for homepage's service widgets, as an environment
    # file: one HOMEPAGE_VAR_<NAME>=<value> per line, referenced from the
    # widgets as {{HOMEPAGE_VAR_<NAME>}}. Read by systemd as root, so owned by
    # root -- homepage itself runs as a DynamicUser and never sees the file.
    homepage.file = ./secrets/homepage.age;
    # The Forgejo Actions runner's own token, alone in the file with no TOKEN=
    # prefix. It pairs with the runner's UUID in forgejo.nix, and both come
    # from Site Administration -> Actions -> Runners -> Create new runner (not
    # the registration token, which the runner module doesn't accept). Read by
    # systemd as root and handed to the runner as a credential.
    forgejo-runner.file = ./secrets/forgejo-runner.age;
  };
  age.identityPaths = [ "/root/.ssh/id_ed25519" ];
}
