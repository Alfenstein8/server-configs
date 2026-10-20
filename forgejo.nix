{ config, pkgs, ... }:
let
  port = 3000;
in
{
  # Forgejo only queues workflow jobs; this runner is what executes them, each in
  # a podman container picked by the job's `runs-on` label. Registers over
  # localhost, so it doesn't depend on the public hostname resolving.
  services.gitea-actions-runner = {
    package = pkgs.forgejo-runner;
    instances.homeserver = {
      enable = true;
      name = "homeserver";
      url = "http://localhost:${toString port}";
      tokenFile = config.age.secrets.forgejo-runner.path;
      labels = [
        "ubuntu-latest:docker://node:20-bookworm"
        "ubuntu-22.04:docker://node:20-bullseye"
        "docker:docker://node:20-bookworm"
      ];
    };
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
