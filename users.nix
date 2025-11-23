{ pkgs, ... }: {
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.groups.alfred = {};
  users.users.alfred = {
    isNormalUser = true;
    description = "Alfred";
    extraGroups = [ "networkmanager" "wheel" "samba-users" "filebrowser" "alfred" ];
    packages = with pkgs; [];
  };

  users.users.zehra = {
    isNormalUser = true;
    description = "Zehra";
    extraGroups = [ "networkmanager" "samba-users" "filebrowser"];
  };

  users.users.ole = {
    isNormalUser = true;
    description = "Ole";
    extraGroups = [ "networkmanager" "samba-users" "filebrowser"];
  };

  users.users.maj-britt = {
    isNormalUser = true;
    description = "Maj-Britt";
    extraGroups = [ "networkmanager" "samba-users" "filebrowser"];
  };

  users.users.esajas = {
    isNormalUser = true;
    description = "Esajas";
    extraGroups = [ "networkmanager" "samba-users" "filebrowser"];
  };

  users.groups.samba-users = {};

  users.users.shared-files = {
    isSystemUser = true;
    description = "Shared Files";
    group = "shared-files";
  };

  users.users.root = {
    extraGroups = [ "alfred" ];
  };

  users.groups.shared-files = {};

  users.groups.media-sccess = {};

  # users.users.deluge = {
  #   extraGroups = [ "media-access" ];
  # };
  #
  # users.users.jellyfin = {
  #   extraGroups = [ "media-access" ];
  # };
}
