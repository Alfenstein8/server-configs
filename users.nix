{ pkgs, ... }:
{
  # Define a user account. Don't forget to set a password with ‘passwd’.
  #
  # Every uid and gid here is pinned to what NixOS had already handed out
  # (read off the server 2026-11-12), so files on /mnt/storage and in backups
  # keep their owners if users are ever added, removed or reordered.
  users.groups.shlammen.gid = 978;
  users.users.shlammen = {
    isSystemUser = true;
    uid = 984;
    description = "Shared household account";
    group = "shlammen";
  };

  users.groups.alfred.gid = 979;
  users.users.alfred = {
    isNormalUser = true;
    # The roms Samba share in romm.nix writes as alfred for RomM's uid 1000
    # user, and romm.nix asserts it.
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
    uid = 1001;
    extraGroups = [
      "networkmanager"
      "samba-users"
      "filebrowser"
      "shlammen"
    ];
  };

  users.users.ole = {
    isNormalUser = true;
    uid = 1004;
    extraGroups = [
      "networkmanager"
      "samba-users"
      "filebrowser"
    ];
  };

  users.users.maj-britt = {
    isNormalUser = true;
    uid = 1003;
    extraGroups = [
      "networkmanager"
      "samba-users"
      "filebrowser"
    ];
  };

  users.users.esajas = {
    isNormalUser = true;
    uid = 1002;
    extraGroups = [
      "networkmanager"
      "samba-users"
      "filebrowser"
    ];
  };

  users.groups.samba-users.gid = 986;

  users.users.shared-files = {
    isSystemUser = true;
    uid = 990;
    description = "Shared Files";
    group = "shared-files";
  };

  users.users.root = {
    extraGroups = [ "alfred" ];
  };

  users.groups.shared-files.gid = 985;

  users.groups.media-sccess = { };

  # users.users.deluge = {
  #   extraGroups = [ "media-access" ];
  # };
  #
  # users.users.jellyfin = {
  #   extraGroups = [ "media-access" ];
  # };
}
