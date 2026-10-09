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
        "hosts allow" = "192.168.0.0/24 10.8.0.0/24 100.64.0.0/10 127.0.0.1 localhost"; # 10.8.0.0/24 is wireguard, 100.64.0.0/10 is the tailnet
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

      "shlammen" = {
        "path" = "/mnt/storage/data/Shares/shlammen";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = [
          "alfred"
          "zehra"
        ];
        "create mask" = "0660";
        "directory mask" = "0770";
        "force user" = "shlammen";
        "force group" = "shlammen";
      };

      "alfred" = {
        "path" = "/mnt/storage/data/Shares/Users/alfred";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "alfred";
        "create mask" = "0660";
        "directory mask" = "0770";
        "force user" = "alfred";
        "force group" = "alfred";
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
        "valid users" = [
          "alfred"
          "ole"
          "maj-britt"
          "esajas"
        ];
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

  networking.firewall.allowPing = true;

  # Share directories, owned to match each share's force user/group and
  # directory mask (Shared stays 0770; navidrome and immich read it through the
  # shared-files group). Existing directories get their owner and mode reset to these.
  systemd.tmpfiles.rules = [
    "d /mnt/storage/data/Shares                 0755 root         root         -"
    "d /mnt/storage/data/Shares/Users           0755 root         root         -"
    "d /mnt/storage/data/Shares/Public          0755 alfred       users        -"
    "d /mnt/storage/data/Shares/shlammen        0770 shlammen     shlammen     -"
    "d /mnt/storage/data/Shares/Shared          0770 shared-files shared-files -"
    "d /mnt/storage/data/Shares/Users/alfred    0770 alfred       alfred       -"
    "d /mnt/storage/data/Shares/Users/zehra     0755 zehra        users        -"
    "d /mnt/storage/data/Shares/Users/ole       0755 ole          users        -"
    "d /mnt/storage/data/Shares/Users/maj-britt 0755 maj-britt    users        -"
    "d /mnt/storage/data/Shares/Users/esajas    0755 esajas       users        -"
  ];

}
