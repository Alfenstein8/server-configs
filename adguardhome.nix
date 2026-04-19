{ ... }:
{
  services.adguardhome = {
    enable = true;
    openFirewall = true;
    host = "0.0.0.0";
    port = 3005;
    settings = {
      users = [
        {
          name = "alfred";
          password = "REMOVED-BCRYPT-HASH";
        }
      ];
      dns = {
        bind_hosts = [
          "127.0.0.1"
          "192.168.0.188"
        ];
        port = 53;
      };
    };
  };

}
