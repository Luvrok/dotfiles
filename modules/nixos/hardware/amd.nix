{ pkgs, ... }:

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
    libva-utils
    libva
    mangohud
    (btop.override { rocmSupport = true; })
  ];

  environment.variables = {
    LIBVA_DRIVER_NAME = "radeonsi";
  };

  hardware.amdgpu.overdrive.enable = true;
  services.lact.enable = true;
}
