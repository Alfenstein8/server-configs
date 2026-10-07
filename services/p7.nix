# P7 Events (https://p7.shlambert.top): the module from P7's own repository (flake input
# `p7`) runs the API server, Synapse on PostgreSQL and the site, and deploys each new
# release of P7 (once its Android APK is attached, so the app and the server update
# together) into /nix/var/nix/profiles/p7 (no rebuild here; see
# P7's README, "Production on NixOS"). Updating the `p7` input only matters when the
# module itself changes.
#
# Public, like zehra.click: the router's WAN 443/80 forwards reach 8443/8880, which
# serve exactly the hosts that name those ports (see ../registry.nix).
#
# Secrets: one agenix environment file, ../secrets/p7.age (ageGen secrets/p7.age).
# Until it exists P7 stays off with a warning, since a missing .age file would break
# evaluation of the whole flake.
#   P7_SHARED_SECRET=  Synapse's registration shared secret; the bot's and guests'
#                      passwords derive from it, so keep it. Any long random string:
#                      head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
#   P7_SMTP_PASS=      the Brevo SMTP key
#   P7_KLIPY_API_KEY=  the KLIPY API key (handed to clients anyway: the GIF picker)
#
# The repository is public: the flake input and each deploy fetch it over HTTPS, and
# the deploy job reads its releases without a token.
{
  config,
  lib,
  inputs,
  ...
}:
let
  ready = builtins.pathExists ../secrets/p7.age;
in
{
  imports = [ inputs.p7.nixosModules.default ];

  warnings = lib.optional (!ready) "P7 is off until secrets/p7.age exists (see services/p7.nix)";

  age.secrets.p7 = lib.mkIf ready { file = ../secrets/p7.age; };

  services.p7 = lib.mkIf ready {
    enable = true;
    domain = config.shlam.services.p7.host;
    # The registry serves the site (below), with the wildcard certificate.
    configureCaddy = false;
    # Split into a file per secret at boot; each service gets only its own.
    secretsFile = config.age.secrets.p7.path;
    smtp = {
      host = "smtp-relay.brevo.com";
      port = 587;
      user = "REMOVED@smtp-brevo.com";
      # Brevo has p7.shlambert.top's SPF/DKIM records.
      from = "p7@p7.shlambert.top";
    };
    # The debug key the Android app is built with for now (mise run app:build).
    androidApp.fingerprints = [
      "79:78:72:26:E2:12:93:2B:7D:D7:DD:8F:03:A9:9A:48:51:0E:54:31:DB:5B:00:FF:FC:DB:E3:70:1F:6B:D7:01"
    ];
    autoDeploy = {
      enable = true;
      # Releases only (mise run release in P7): merging to main doesn't go live.
      track = "release";
      flakeUrl = "git+https://codefloe.com/Alfert/p7-events.git";
      forgeUrl = "https://codefloe.com";
      repository = "Alfert/p7-events";
      # Public repository: no token (an invalid one would be refused, even there).
      tokenFile = null;
    };
  };

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
