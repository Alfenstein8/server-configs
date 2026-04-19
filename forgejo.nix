{
  services.forgejo = {
    enable = true;
    stateDir = "/mnt/storage/data/forgejo";
    settings = {
      server = {
        DOMAIN = "git.shlambert.top";
        ROOT_URL = "https://git.shlambert.top";
        HTTP_PORT = 3000;
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

}
