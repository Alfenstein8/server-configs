{ config, pkgs, ... }:
# Tags Radarr movies and Sonarr series `private` when qBittorrent holds a
# private-tracker torrent for them, so the libraries can be pruned with that in
# view. Builds on qbit-manage's `private` torrent tag (./qbit-manage.nix), and
# reuses its qBittorrent login. The matching rules are in ./private-tags.py.
#
# Deleting a tagged movie in Radarr does not stop the torrent seeding -- it only
# removes the library hardlink -- but it frees no space either, since the
# torrent still holds the data and qbit-manage never deletes private torrents.
let
  qbt = config.services.qbit-manage.settings.qbt;
in
{
  systemd.services.arr-private-tags = {
    description = "Tag Radarr/Sonarr items that have a private-tracker torrent";
    after = [
      "podman-radarr.service"
      "podman-sonarr.service"
      "podman-qbittorrent.service"
    ];
    environment = {
      QBT_URL = "http://${qbt.host}";
      QBT_USER = qbt.user;
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${./private-tags.py}";
      # QBIT_PASS, the same file qbit-manage reads.
      EnvironmentFile = config.age.secrets.qbit-manage.path;
      # The API keys sit in each app's config.xml, owned by the containers'
      # user; systemd hands copies to the dynamic user instead.
      LoadCredential = [
        "radarr:/mnt/appdata/radarr/config.xml"
        "sonarr:/mnt/appdata/sonarr/config.xml"
      ];
      DynamicUser = true;
      ProtectHome = true;
      PrivateDevices = true;
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
      ];
    };
  };

  systemd.timers.arr-private-tags = {
    wantedBy = [ "timers.target" ];
    # One small API call per private torrent and a few per app -- seconds of
    # work, so hourly costs nothing.
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "5m";
    };
  };
}
