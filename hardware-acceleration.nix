{ pkgs, ... }:
{
  # 1. enable vaapi on OS-level
  # nixpkgs.config.packageOverrides = pkgs: {
  #   vaapiIntel = pkgs.vaapiIntel.override { enableHybridCodec = true; };
  # };
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      intel-media-driver
      # intel-vaapi-driver
      opencl-headers
      libva-vdpau-driver
      intel-vaapi-driver
      libvdpau-va-gl
      # intel-compute-runtime # OpenCL filter support (hardware tonemapping and subtitle burn-in)
      intel-compute-runtime-legacy1
      # intel-ocl
      # intel-media-sdk # QSV up to 11th gen
      vpl-gpu-rt
    ];
  };
}
