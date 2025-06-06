{ pkgs, ... }: {
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.alfred = {
    isNormalUser = true;
    description = "Alfred";
    extraGroups = [ "networkmanager" "wheel" "samba-users"];
    packages = with pkgs; [];
  };

  users.users.zehra = {
    isNormalUser = true;
    description = "Zehra";
    extraGroups = [ "networkmanager" "samba-users"];
  };

  users.users.ole = {
    isNormalUser = true;
    description = "Ole";
    extraGroups = [ "networkmanager" "samba-users"];
  };

  users.users.maj-britt = {
    isNormalUser = true;
    description = "Maj-Britt";
    extraGroups = [ "networkmanager" "samba-users"];
  };

  users.users.esajas = {
    isNormalUser = true;
    description = "Esajas";
    extraGroups = [ "networkmanager" "samba-users"];
  };

  users.groups.samba-users = {};

  users.users.shared-files = {
    isSystemUser = true;
    description = "Shared Files";
    group = "shared-files";
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
