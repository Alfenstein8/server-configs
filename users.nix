{ pkgs, ... }:
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.groups.shlammen = { };
  users.users.shlammen = {
    isSystemUser = true;
    description = "Shared household account";
    group = "shlammen";
  };

  users.groups.alfred = { };
  users.users.alfred = {
    isNormalUser = true;
    # What it already was, pinned: the roms Samba share in romm.nix writes as
    # alfred for RomM's uid 1000 user.
    uid = 1000;
    description = "Alfred";
    extraGroups = [
      "networkmanager"
      "wheel"
      "samba-users"
      "filebrowser"
      "alfred"
      "shlammen"
    ];
    packages = with pkgs; [ ];
  };

  users.users.zehra = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "samba-users"
      "filebrowser"
      "shlammen"
    ];
  };

  users.users.ole = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "samba-users"
      "filebrowser"
    ];
  };

  users.users.maj-britt = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "samba-users"
      "filebrowser"
    ];
  };

  users.users.esajas = {
    isNormalUser = true;
    extraGroups = [
      "networkmanager"
      "samba-users"
      "filebrowser"
    ];
  };

  users.groups.samba-users = { };

  users.users.shared-files = {
    isSystemUser = true;
    description = "Shared Files";
    group = "shared-files";
  };

  users.users.root = {
    extraGroups = [ "alfred" ];
  };

  users.groups.shared-files = { };

  users.groups.media-sccess = { };

  # users.users.deluge = {
  #   extraGroups = [ "media-access" ];
  # };
  #
  # users.users.jellyfin = {
  #   extraGroups = [ "media-access" ];
  # };
}
