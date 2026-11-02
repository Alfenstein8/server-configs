{ lib, ... }:
let
  port = 3080;
in
{
  virtualisation.oci-containers.containers."watcharr" = {
    image = "ghcr.io/sbondco/watcharr:v4.3.0";
    volumes = [
      "/mnt/appdata/watcharr:/data:rw"
    ];
    ports = [
      "${toString port}:${toString port}/tcp"
    ];
    log-driver = "journald";
    extraOptions = [
      # Run the container inside podman-watcharr.service's own cgroup (split
      # between conmon and the payload) rather than a /machine.slice scope, so
      # systemd and cAdvisor see its memory and CPU under the unit's name.
      # Overrides the module's --cgroups=enabled: these come later, and the
      # last one wins. The unit already has Delegate=true, which this needs.
      # Trial for the rest of the containers.
      "--cgroups=split"
      "--ip=172.39.0.7"
      "--network-alias=watcharr"
      "--network=servarrnetwork"
    ];
  };
  systemd.services."podman-watcharr" = {
    serviceConfig = {
      Restart = lib.mkOverride 90 "always";
    };
    after = [
      "podman-network-servarrnetwork.service"
    ];
    requires = [
      "podman-network-servarrnetwork.service"
    ];
    partOf = [
      "podman-compose-arr-stack-root.target"
    ];
    wantedBy = [
      "podman-compose-arr-stack-root.target"
    ];
  };

  shlam.services.watcharr = {
    subdomain = "watchlist";
    inherit port;
    dashboard = {
      title = "Watcharr";
      group = "Media";
      order = 30;
      icon = "watcharr-light.webp";
      description = "Watch list";
    };
  };
}
