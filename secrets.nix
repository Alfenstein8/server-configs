{
  age.secrets = {
    spaceship.file = ./secrets/spaceship.age;
    restic.file = ./secrets/restic.age;
    backblaze.file = ./secrets/backblaze.age;
    immich.file = ./secrets/immich.age;
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
    # Grafana's Discord webhook, as an environment file:
    # DISCORD_WEBHOOK_URL=<url>. Read by systemd as root, so owned by root.
    grafana-discord.file = ./secrets/grafana-discord.age;
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
  };
  age.identityPaths = [ "/root/.ssh/id_ed25519" ];
}
