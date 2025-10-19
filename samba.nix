{
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        "workgroup" = "WORKGROUP";
        "server string" = "shlamb";
        "netbios name" = "shlamb";
        security = "user";
        "hosts allow" = "192.168.0. 127.0.0.1 localhost";
        "hosts deny" = "0.0.0.0/0";
        "guest account" = "nobody";
        "map to guest" = "bad user";
	# "interfaces" = "wlp4s0"; # Change or remove this on new server
        # "bind interfaces only" = "yes";
      };
  
      "public" = {
        "path" = "/mnt/storage/data/Shares/Public";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "yes";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "alfred";
        "force group" = "users";
      };
  
      "alfred" = {
        "path" = "/mnt/storage/data/Shares/Users/alfred";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "alfred";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "alfred";
        "force group" = "users";
      };
  
      "zehra" = {
        "path" = "/mnt/storage/data/Shares/Users/zehra";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "zehra";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "zehra";
        "force group" = "users";
      };

      "ole" = {
        "path" = "/mnt/storage/data/Shares/Users/ole";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "ole";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "ole";
        "force group" = "users";
      };
  
      "maj-britt" = {
        "path" = "/mnt/storage/data/Shares/Users/maj-britt";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "maj-britt";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "maj-britt";
        "force group" = "users";
      };
  
      "esajas" = {
        "path" = "/mnt/storage/data/Shares/Users/esajas";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "esajas";
        "create mask" = "0644";
        "directory mask" = "0755";
        "force user" = "esajas";
        "force group" = "users";
      };
  
      "shared" = {
        "path" = "/mnt/storage/data/Shares/Shared";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "@samba-users";
        "create mask" = "0664"; # Allow owner/group to read/write, others no (Unix permissions will enforce)
        "directory mask" = "0775"; # Allow owner/group to rwx, others rx
        "force user" = "shared-files";
        "force group" = "shared-files";
      };
    };
  };
  
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };
  
  networking.firewall.enable = true;
  networking.firewall.allowPing = true;

}
