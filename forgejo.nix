{ config, ... }:
let
  port = 3000;
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
