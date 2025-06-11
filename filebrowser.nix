{
  services.filebrowser = {
    enable = true;
    group = "users";
    settings = {
      port = 8085;
      root = "/";
    };
  };

  users.users.filebrowser = {
    extraGroups = [ "users" "shared-files" ];
  };

  services.caddy.virtualHosts."http://filebrowser.shlambert.top".extraConfig = ''
    reverse_proxy localhost:8085
    '';
}
