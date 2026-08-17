{ config, ... }:
let
  port = 3000;
in
{
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
      service.DISABLE_REGISTRATION = false;
      actions = {
        ENABLED = true;
        DEFAULT_ACTIONS_URL = "github";
      };
    };
    lfs.enable = true;
  };

  shlam.services.forgejo = {
    subdomain = "git";
    inherit port;
    dashboard = {
      title = "Forgejo";
      group = "Infrastructure";
      order = 30;
      icon = "forgejo.svg";
      description = "Git Hosting";
    };
  };
}
