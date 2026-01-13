{ config, pkgs, lib, ... }:

{
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  hardware.enableRedistributableFirmware = true;

  environment.systemPackages = with pkgs; [
    amdgpu_top
    lm_sensors
    dmidecode
    vulkan-tools
    libva-vdpau-driver
    libvdpau-va-gl
    libva-utils
    libva
    mangohud
    (btop.override { rocmSupport = true; })
  ];

  environment.etc."X11/xorg.conf.d/10-amdgpu.conf".text = ''
    Section "Device"
        Identifier "AMD"
        Driver "amdgpu"
        Option "TearFree" "true"
        Option "DRI" "3"
        Option "Hotplug" "false"
    EndSection
  '';

  environment.variables = {
    LIBVA_DRIVER_NAME = "radeonsi";
  };
}
