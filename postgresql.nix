{
  services.postgresql = {
    enable = true;
    roles = [
      {
        name = "netdata";
      }
    ];
  };
}
