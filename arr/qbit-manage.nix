{ config, ... }:
# Deletes finished torrents from qBittorrent once they are no longer worth
# keeping. A torrent is removed, files and all, only when ALL of these hold:
#
#   - it is not from a private tracker (qbm tags those `private`),
#   - its ratio has reached 3,
#   - Radarr/Sonarr no longer use it: none of its files are hardlinked into the
#     library (qbm tags those `noHL`). An upgraded or deleted movie/episode
#     leaves its old torrent unlinked; a live one stays hardlinked.
#
# Deleting a hardlinked torrent would free almost nothing anyway -- the library
# file is the same data -- so the torrents this is allowed to remove are
# exactly the ones taking space of their own. Only the radarr and tv-sonarr
# categories are ever tagged noHL, so hand-added torrents are never touched.
let
  # qBittorrent runs in a container and reports its paths as /data/...; the
  # module has no remote_dir option to translate them, so qbm gets the same
  # view through a bind mount instead (see serviceConfig below).
  media = "/mnt/storage/data/media";
  completed = "/data/downloads/qbittorrent/completed";
in
{
  services.qbit-manage = {
    enable = true;
    # QBIT_PASS=<qBittorrent WebUI password>
    environmentFile = config.age.secrets.qbit-manage.path;

    commands = {
      schedule = 60; # minutes
      startupDelay = 120;
      # Tagging was run on its own first and checked in qBittorrent. With
      # shareLimits on, the unused-public group below stops and deletes. Set it
      # back to false to return to tagging only.
      tagUpdate = true;
      tagNoHardLinks = true;
      shareLimits = true;
    };

    settings = {
      # gluetun publishes qBittorrent's WebUI on the host.
      qbt = {
        host = "localhost:8080";
        user = "alfred";
        pass = "!ENV QBIT_PASS";
      };

      settings = {
        private_tag = "private";
        nohardlinks_tag = "noHL";
        tag_stalled_torrents = false;
        # Leave qBittorrent's own global share limits alone; only the group
        # below gets limits set by qbm.
        disable_qbt_default_share_limits = false;
      };

      directory.root_dir = "/data/downloads/";

      # Both categories have an empty save_path in qBittorrent, which puts
      # them under the default save path.
      cat = {
        radarr = "${completed}/radarr";
        tv-sonarr = "${completed}/tv-sonarr";
      };

      # tag_update needs a tracker section; every torrent without a more
      # specific entry gets this tag.
      tracker.other.tag = "other";

      nohardlinks = {
        # Hardlinks inside root_dir (another torrent) don't count as "in use".
        global_options.ignore_root_dir = true;
        radarr = { };
        tv-sonarr = { };
      };

      share_limits.unused-public = {
        priority = 1;
        categories = [
          "radarr"
          "tv-sonarr"
        ];
        include_all_tags = [ "noHL" ];
        exclude_any_tags = [ "private" ];
        max_ratio = 3;
        # Stop at ratio 3, then qbm's cleanup removes it on its next run.
        share_limit_action = "Stop";
        cleanup = true;
      };

      # Delete straight through qBittorrent. A recycle bin would need qbm to
      # move files owned by the containers' user, and these are re-acquirable.
      recyclebin.enabled = false;
    };
  };

  systemd.services.qbit-manage.serviceConfig.BindReadOnlyPaths = [ "${media}:/data" ];
}
