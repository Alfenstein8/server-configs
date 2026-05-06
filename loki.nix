{
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;

      server.http_listen_port = 3100;

      target = "all"; # single-binary mode, runs all components in one process

      common.ring.kvstore.store = "memberlist"; # no Consul needed
      schema_config.configs = [
        {
          from = "2025-01-01";
          store = "tsdb";
          object_store = "filesystem";
          schema = "v13";
          index = {
            prefix = "index_";
            period = "24h";
          };
        }
      ];

      storage_config = {
        tsdb_shipper = {
          active_index_directory = "/var/lib/loki/tsdb-index";
          cache_location = "/var/lib/loki/tsdb-cache";
        };
        filesystem.directory = "/var/lib/loki/chunks";
      };

      compactor.working_directory = "/var/lib/loki/compactor";

      limits_config = {
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };
    };
  };
}
