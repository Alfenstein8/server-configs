{ config, ... }:
let
  # The shares that name people (their own folders, and who may use the shared
  # ones) live in secrets/samba-shares.age rather than here, in smb.conf syntax.
  # Edit with ageGen; samba restarts on its own.
  shares = config.age.secrets.samba-shares.path;
in
{
  age.secrets.samba-shares.file = ./secrets/samba-shares.age;

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

      # Included last, so its shares come after all of [global] and inherit its
      # share defaults (the module's `invalid users = root` among them); an
      # include inside [global] would land mid-section, keys being sorted. The
      # section itself is a disabled, hidden stub: Samba wants one to hold it.
      "zz-private-shares" = {
        available = "no";
        browseable = "no";
        include = shares;
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
        "create mask" = "0660";
        "directory mask" = "0770";
        "force user" = "alfred";
        "force group" = "alfred";
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
  # The per-person folders under Users/ aren't listed: their names would be here.
  systemd.tmpfiles.rules = [
    "d /mnt/storage/data/Shares                 0755 root         root         -"
    "d /mnt/storage/data/Shares/Users           0755 root         root         -"
    "d /mnt/storage/data/Shares/Public          0755 alfred       users        -"
    "d /mnt/storage/data/Shares/shlammen        0770 shlammen     shlammen     -"
    "d /mnt/storage/data/Shares/Shared          0770 shared-files shared-files -"
    "d /mnt/storage/data/Shares/Users/alfred    0770 alfred       alfred       -"
  ];

  # A changed samba-shares.age leaves the unit untouched, so nothing would
  # restart smbd to pick it up. The .age file's store path changes with it.
  systemd.services.samba-smbd.restartTriggers = [ config.age.secrets.samba-shares.file ];
}
