{ config, lib, modulesPath, ... }: 

{
  imports =
    [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/" =
    { device = "/dev/disk/by-uuid/f5eeeeaf-a26d-43a4-bc72-6e652a5018f4";
      fsType = "ext4";
    };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/D972-763B";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  swapDevices = [{ device = "/dev/disk/by-uuid/69cd13c1-0608-4c52-8947-2a3ae000e4f3"; }];

  hardware.enableAllFirmware = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;

  time.hardwareClockInLocalTime = false;
}
