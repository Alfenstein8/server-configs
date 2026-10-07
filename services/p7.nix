# P7 Events (https://p7.shlambert.top): the module from P7's own repository (flake input
# `p7`) runs the API server, Synapse on PostgreSQL and the site, and deploys each new
# commit on main whose CI passed into /nix/var/nix/profiles/p7 (no rebuild here; see
# P7's README, "Production on NixOS"). Updating the `p7` input only matters when the
# module itself changes.
#
# Public, like zehra.click: the router's WAN 443/80 forwards reach 8443/8880, which
# serve exactly the hosts that name those ports (see ../registry.nix).
#
# Secrets (agenix, ../secrets): until all of them exist P7 stays off with a warning,
# since a missing .age file would break evaluation of the whole flake.
#   p7-shared-secret  Synapse's registration shared secret; the bot's and guests'
#                     passwords derive from it, so keep it. Any long random string:
#                     head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
#   p7-smtp-pass      the Brevo SMTP key
#   p7-klipy-key      the KLIPY API key (handed to clients anyway: the GIF picker)
#   p7-forge-token    CodeFloe access token: read the repository (commit statuses)
#
# The repository is private, and fetched over SSH with a read-only deploy key that
# lives outside the repo, like the Storage Box key in ../backup.nix: the flake input
# is fetched while evaluating, before agenix has decrypted anything. Once, as root:
#   ssh-keygen -t ed25519 -N "" -C p7-deploy -f /root/.ssh/p7-deploy
# and add /root/.ssh/p7-deploy.pub to the repository's deploy keys (read-only).
{
  config,
  lib,
  inputs,
  ...
}:
let
  secrets = [
    "p7-shared-secret"
    "p7-smtp-pass"
    "p7-klipy-key"
    "p7-forge-token"
  ];
  deployKey = "/root/.ssh/p7-deploy";
  file = name: ../secrets/${name}.age;
  missing = builtins.filter (name: !builtins.pathExists (file name)) secrets;
  ready = missing == [ ];
  secret = name: config.age.secrets.${name}.path;
in
{
  imports = [ inputs.p7.nixosModules.default ];

  warnings = lib.optional (!ready) (
    "P7 is off until its secrets exist (services/p7.nix): "
    + lib.concatMapStringsSep ", " (name: "secrets/${name}.age") missing
  );

  age.secrets = lib.mkIf ready (lib.genAttrs secrets (name: { file = file name; }));

  services.p7 = lib.mkIf ready {
    enable = true;
    domain = config.shlam.services.p7.host;
    # The registry serves the site (below), with the wildcard certificate.
    configureCaddy = false;
    sharedSecretFile = secret "p7-shared-secret";
    smtp = {
      host = "smtp-relay.brevo.com";
      port = 587;
      user = "REMOVED@smtp-brevo.com";
      passwordFile = secret "p7-smtp-pass";
      # Brevo has p7.shlambert.top's SPF/DKIM records.
      from = "p7@p7.shlambert.top";
    };
    klipyKeyFile = secret "p7-klipy-key";
    # The debug key the Android app is built with for now (mise run app:build).
    androidApp.fingerprints = [
      "79:78:72:26:E2:12:93:2B:7D:D7:DD:8F:03:A9:9A:48:51:0E:54:31:DB:5B:00:FF:FC:DB:E3:70:1F:6B:D7:01"
    ];
    autoDeploy = {
      enable = true;
      flakeUrl = "git+ssh://git@codefloe.com/Alfert/p7-events.git";
      forgeUrl = "https://codefloe.com";
      repository = "Alfert/p7-events";
      tokenFile = secret "p7-forge-token";
      sshKeyFile = deployKey;
    };
  };

  # Fetching P7 (the flake input during a rebuild, and each deploy) over SSH.
  programs.ssh.knownHosts."codefloe.com".publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF0iVzx4KlQQGYTrEmXBaBQstbwMowbgAEXziPk5DST5";
  # Root only: your own user's SSH to CodeFloe keeps its own keys.
  programs.ssh.extraConfig = ''
    Match host codefloe.com localuser root
      IdentityFile ${deployKey}
      IdentitiesOnly yes
  '';

  shlam.services.p7 = {
    # No port: the module's site (app, API, Synapse routes) is the whole vhost body.
    extraConfig = lib.mkIf ready config.services.p7.caddySite;
    vhost = ready;
    publicPort = if ready then 8443 else null;
    publicHttpPort = if ready then 8880 else null;
    dashboard = {
      title = "P7 Events";
      group = "Productivity & Utilities";
      order = 90;
      icon = "mdi-calendar-account";
      description = "Make plans with friends";
    };
  };

  # The API server's state (its own database) and Synapse's signing key and media.
  # Synapse's database is in PostgreSQL, which ../backup.nix already dumps.
  services.restic.backups.storagebox.paths = lib.mkIf ready [
    "/var/lib/private/p7"
    "/var/lib/matrix-synapse"
  ];
}
