{
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  networking.hostId = "70c2c486";

  # Reads every block and repairs it from the other side of the mirror if its
  # checksum fails. First Sunday of the month, at night: a full pass keeps both
  # disks busy for 10-15 hours.
  services.zfs.autoScrub = {
    enable = true;
    pools = [ "storage" ];
    interval = "Sun *-*-01..07 02:00";
  };
}
