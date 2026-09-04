{ lib, modulesPath, ... }:

{
  imports =
    [ (modulesPath + "/profiles/qemu-guest.nix")
    ];

  boot.initrd.availableKernelModules = [ "ata_piix" "uhci_hcd" "virtio_pci" "virtio_scsi" "sd_mod" "sr_mod" ];
  boot.initrd.kernelModules = [ "dm-snapshot" "dm-mod" ];
  boot.initrd.systemd.enable = true;
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  swapDevices = [ ];

  # fileSystems."/" = {
  #   device = "/dev/disk/by-uuid/0d5fa1f4-7cdf-4b31-a50a-30de589a7629";
  #   fsType = "ext4";
  # };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
