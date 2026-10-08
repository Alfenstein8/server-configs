{
  services.loki = {
    enable = true;
    configuration = {
      auth_enabled = false;

      # Only Grafana and the log shipper talk to it, both on this host.
      server = {
        http_listen_address = "127.0.0.1";
        http_listen_port = 3100;
        grpc_listen_address = "127.0.0.1";
      };

      target = "all"; # single-binary mode, runs all components in one process

      # One process, one copy. The default replication factor is 3, which a
      # single instance can never satisfy -- every push and query then fails
      # with "too many unhealthy instances in the ring". An in-memory ring is
      # all a lone process needs; memberlist only matters across several.
      common = {
        path_prefix = "/var/lib/loki";
        replication_factor = 1;
        ring = {
          instance_addr = "127.0.0.1";
          kvstore.store = "inmemory";
        };
      };

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

      # Retention is the compactor's job, and it is off unless asked for --
      # without this, /var/lib/loki on the root disk only ever grows.
      compactor = {
        working_directory = "/var/lib/loki/compactor";
        retention_enabled = true;
        delete_request_store = "filesystem";
      };

      limits_config = {
        retention_period = "30d";
        reject_old_samples = true;
        reject_old_samples_max_age = "168h";
      };
    };
  };
}
