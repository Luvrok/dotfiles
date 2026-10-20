{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    libva-utils
    intel-gpu-tools
    nvtopPackages.full

    mesa
    driversi686Linux.mesa

    libinput-gestures

    nvidia-vaapi-driver
    vulkan-tools

    intel-compute-runtime
    intel-media-driver
    libva-vdpau-driver
    libvdpau-va-gl
    intel-vaapi-driver
    (btop.override { cudaSupport = true; })
  ];

  # sway won't start while the nvidia module is loaded. the intel gpu drives
  # the panel, nvidia only renders what nvidia-offload starts
  programs.sway.extraOptions = [ "--unsupported-gpu" ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
      extraPackages = with pkgs; [
        intel-compute-runtime
        intel-media-driver
        libva-vdpau-driver
        libvdpau-va-gl
        intel-vaapi-driver
        nvidia-vaapi-driver
      ];
    };

    nvidia = {
      modesetting.enable = true;
      powerManagement = {
        enable = true;
        finegrained = false;
      };

      open = true;
      nvidiaSettings = true;
      # package = config.boot.kernelPackages.nvidiaPackages.stable;

      prime = {
        offload.enable = true;
        offload.enableOffloadCmd = true;
        intelBusId = "PCI:0:2:0";
        nvidiaBusId = "PCI:1:0:0";
      };
    };
  };
}
