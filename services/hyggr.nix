# Hyggr (https://hyggr.shlambert.top), formerly P7 Events: the module from Hyggr's own
# repository (flake input `hyggr`) runs the API server, Synapse on PostgreSQL and the
# site, and deploys each new release of Hyggr (once its Android APK is attached, so the
# app and the server update together) into /nix/var/nix/profiles/hyggr (no rebuild
# here; see Hyggr's README, "Production on NixOS"). Updating the `hyggr` input only
# matters when the module itself changes.
#
# Public, like zehra.click: the router's WAN 443/80 forwards reach 8443/8880, which
# serve exactly the hosts that name those ports (see ../registry.nix).
#
# Secrets: one agenix environment file, ../secrets/hyggr.age (ageGen secrets/hyggr.age).
# Until it exists Hyggr stays off with a warning, since a missing .age file would break
# evaluation of the whole flake.
#   HYGGR_SHARED_SECRET=  Synapse's registration shared secret; the bot's and guests'
#                         passwords derive from it, so keep it. Any long random string:
#                         head -c 32 /dev/urandom | od -An -tx1 | tr -d ' \n'
#   HYGGR_SMTP_PASS=      the Brevo SMTP key
#   HYGGR_KLIPY_API_KEY=  the KLIPY API key (handed to clients anyway: the GIF picker)
#
# Push to the Android app through Google (Firebase project hyggr-events): the service
# account key is ../secrets/hyggr-firebase.age (JSON, from the Firebase console's
# Service accounts tab), the app's ./hyggr-google-services.json isn't secret (the app
# gets its values from the instance). UnifiedPush needs nothing here.
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
  ready = builtins.pathExists ../secrets/hyggr.age;
in
{
  imports = [ inputs.hyggr.nixosModules.default ];

  warnings = lib.optional (!ready) "Hyggr is off until secrets/hyggr.age exists (see services/hyggr.nix)";

  age.secrets.hyggr = lib.mkIf ready { file = ../secrets/hyggr.age; };
  age.secrets.hyggr-firebase = lib.mkIf ready { file = ../secrets/hyggr-firebase.age; };

  services.hyggr = lib.mkIf ready {
    enable = true;
    domain = config.shlam.services.hyggr.host;
    # The registry serves the site (below), with the wildcard certificate.
    configureCaddy = false;
    # Split into a file per secret at boot; each service gets only its own.
    secretsFile = config.age.secrets.hyggr.path;
    firebase = {
      serviceAccountFile = config.age.secrets.hyggr-firebase.path;
      googleServicesFile = ./hyggr-google-services.json;
    };
    smtp = {
      host = "smtp-relay.brevo.com";
      port = 587;
      user = "REMOVED@smtp-brevo.com";
      # Brevo has hyggr.shlambert.top's SPF/DKIM records.
      from = "hyggr@hyggr.shlambert.top";
    };
    # Keys the Android app is signed with, for App Links: the release key (releases,
    # installed through Obtainium) and the laptop's debug key (mise run app:build).
    androidApp.fingerprints = [
      "0B:83:5E:C1:08:3F:5B:8C:6F:8C:18:98:BB:B5:19:D1:B7:29:42:BA:03:BE:2D:0B:74:4F:12:6D:18:36:6A:07"
      "79:78:72:26:E2:12:93:2B:7D:D7:DD:8F:03:A9:9A:48:51:0E:54:31:DB:5B:00:FF:FC:DB:E3:70:1F:6B:D7:01"
    ];
    autoDeploy = {
      enable = true;
      # Releases only (mise run release in Hyggr): merging to main doesn't go live.
      track = "release";
      flakeUrl = "git+https://codefloe.com/Alfert/hyggr.git";
      forgeUrl = "https://codefloe.com";
      repository = "Alfert/hyggr";
      # Public repository: no token (an invalid one would be refused, even there).
      tokenFile = null;
    };
  };

  shlam.services.hyggr = {
    # No port: the module's site (app, API, Synapse routes) is the whole vhost body.
    extraConfig = lib.mkIf ready config.services.hyggr.caddySite;
    vhost = ready;
    publicPort = if ready then 8443 else null;
    publicHttpPort = if ready then 8880 else null;
    dashboard = {
      title = "Hyggr";
      group = "Productivity & Utilities";
      order = 90;
      icon = "mdi-calendar-account";
      description = "Make plans with friends";
    };
  };

  # Synapse 1.162.0's tests fail on nixpkgs 2026-10-17 (tests.handlers.test_oidc
  # test_map_userinfo_to_user), so it isn't in the binary cache and won't build. That's
  # OIDC login, which this Synapse doesn't configure. Drop this once Synapse is cached
  # again.
  nixpkgs.overlays = [
    (final: prev: {
      matrix-synapse-unwrapped = prev.matrix-synapse-unwrapped.overridePythonAttrs {
        doCheck = false;
      };
    })
  ];

  # The API server's state (its own database) and Synapse's signing key and media.
  # Synapse's database is in PostgreSQL, which ../backup.nix already dumps.
  services.restic.backups.storagebox.paths = lib.mkIf ready [
    "/var/lib/private/hyggr"
    "/var/lib/matrix-synapse"
  ];
}
