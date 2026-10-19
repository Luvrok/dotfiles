{ lib, pkgs, ... }:

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

  users.extraGroups.input.members = [ "monk" ];
}
