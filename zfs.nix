{
  boot.supportedFilesystems = [ "zfs" ];
  boot.zfs.forceImportRoot = false;
  networking.hostId = "70c2c486";

  # Cap the ARC at 32 GiB. OpenZFS now defaults to all RAM minus 1 GiB, and the
  # ARC is slow to give memory back: before the 64 GB upgrade it held ~6 GB
  # while ~6 GB of the services sat in swap. The hit rate was already 97% with
  # that 6 GB, so a bigger ARC buys little.
  boot.kernelParams = [ "zfs.zfs_arc_max=${toString (32 * 1024 * 1024 * 1024)}" ];

  # Reads every block and repairs it from the other side of the mirror if its
  # checksum fails. First Sunday of the month, at night: a full pass keeps both
  # disks busy for 10-15 hours.
  services.zfs.autoScrub = {
    enable = true;
    pools = [ "storage" ];
    interval = "Sun *-*-01..07 02:00";
  };
}
