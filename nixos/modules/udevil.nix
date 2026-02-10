{ config, lib, pkgs, ... }:

{
  programs.udevil.enable = true;
  services.udisks2.enable = lib.mkForce false;
  services.fstrim.enable = true;

  environment.systemPackages = with pkgs; [
    sshfs
    exfat
    ntfs3g
    hfsprogs
    udevil
  ];

  services.udev.packages = with pkgs; [
    # android-udev-rules
  ];

  environment.etc."udevil/udevil.conf".text = ''
    allowed_devices = /dev/sd*, /dev/nvme*
    allowed_internal_devices = /dev/sd*, /dev/nvme*

    allowed_media_dirs = /media

    allowed_users = *
    allowed_groups = *
    default_options = uid=1000,gid=100,umask=0077
  '';

  # Sony DualSense Wireless-Controller; bluetooth; USB
  services.udev.extraRules = ''
    # PS5 DualSense controller over USB hidraw
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0ce6", MODE="0660", TAG+="uaccess"

    # ATTRS{name}=="Sony Interactive Entertainment Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    # ATTRS{name}=="Wireless Controller Touchpad", ENV{LIBINPUT_IGNORE_DEVICE}="1"

    # PS5 DualSense controller over bluetooth hidraw
    KERNEL=="hidraw*", KERNELS=="*054C:0CE6*", MODE="0660", TAG+="uaccess"

    # PS5 DualSense Edge controller over USB hidraw
    KERNEL=="hidraw*", ATTRS{idVendor}=="054c", ATTRS{idProduct}=="0df2", MODE="0660", TAG+="uaccess"

    # PS5 DualSense Edge controller over bluetooth hidraw
    KERNEL=="hidraw*", KERNELS=="*054C:0DF2*", MODE="0660", TAG+="uaccess"

    # i2c support
    KERNEL=="i2c-[0-9]*", GROUP="i2c", MODE="0660"
  '';
  users.extraGroups.input.members = [ "monk" ];
}
