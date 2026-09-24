# Intel iGPU + NVIDIA dGPU laptop with PRIME offload.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  config = lib.mkIf (config.galaxy.host.gpu == "nvidia") {
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
    environment.etc."X11/xorg.conf.d/10-nvidia.conf".text = ''
      Section "ServerLayout"
        Identifier "layout"
        Screen 0 "intel"
        Inactive "nvidia"
      EndSection

      Section "Device"
        Identifier "nvidia"
        Driver "nvidia"
        BusID "PCI:1:0:0"
        Option "PrimaryGPU" "false"
      EndSection

      Section "Screen"
        Identifier "nvidia"
        Device "nvidia"
      EndSection

      Section "Device"
        Identifier "intel"
        Driver "modesetting"
        BusID "PCI:0:2:0"
        Option "TearFree" "true"
      EndSection

      Section "Screen"
        Identifier "intel"
        Device "intel"
      EndSection
    '';

  };
}
