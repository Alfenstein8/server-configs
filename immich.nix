{ config, ... }:
{
  services.immich = {
    enable = true;
    mediaLocation = "/mnt/storage/data/immich";
    port = 2283;
    accelerationDevices = null;
    environment = {
      IMMICH_TELEMETRY_INCLUDE = "all";
      IMMICH_API_METRICS_PORT = "8083";
      IMMICH_MICROSERVICES_METRICS_PORT = "8084";
    };
    settings = {
      newVersionCheck.enabled = false;
      storageTemplate = {
        enabled = true;
        template = "{{y}}/{{MM}}/{{filename}}";
      };

      # Single sign-on through Authelia, next to the password login rather than
      # instead of it (passwordLogin keeps its default, on). Existing sessions
      # are untouched.
      #
      # A login is matched to the Immich account with the same email, so an
      # Authelia email must match the Immich one (Administration -> Users).
      # autoRegister is off so that a mismatch fails at login rather than
      # quietly creating a second, empty account.
      #
      # The claim settings stay at their defaults on purpose. Immich only
      # rewrites an existing user's storage label -- the folder their library
      # lives in -- from storageLabelClaim when it has been changed from the
      # default, and quota and admin role only from immich_quota/immich_role,
      # which Authelia does not send.
      oauth = {
        enabled = true;
        issuerUrl = config.shlam.services.auth.url;
        clientId = "immich";
        # Root-owned is fine: the module reads it with LoadCredential.
        clientSecret._secret = config.age.secrets.immich-oidc.path;
        buttonText = "Login with Authelia";
        autoRegister = false;
      };
    };
  };
  shlam.services.immich = {
    port = config.services.immich.port;
    dashboard = {
      title = "Immich";
      group = "File Management";
      shared = true;
      order = 10;
      icon = "immich.svg";
      description = "Photo & Video Backup";
      # version 2 is the API from immich 1.118 on. The key must belong to an
      # admin: the server statistics endpoint is admin-only.
      extra.widget = {
        type = "immich";
        url = "http://localhost:${toString config.services.immich.port}";
        key = "{{HOMEPAGE_VAR_IMMICH_KEY}}";
        version = 2;
      };
    };
  };

  users.users.immich.extraGroups = [
    "video"
    "render"
    "shared-files"
    "users"
    "alfred"
  ];
}
