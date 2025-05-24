{
  services.pingvin-share = {
    enable = true;
    hostname = "share.shlambert.top";
    dataDir = "/mnt/storage/pingvin-share";
    frontend.port = 3000;
    backend.port = 8080;
  };
}
