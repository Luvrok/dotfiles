{ config, pkgs, lib, ... }:

{
  hardware.keyboard.qmk.enable = true;

  environment.systemPackages = with pkgs; [
    qmk
    vial
    via
  ];

  services.udev.extraRules = ''
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="cb10", ATTRS{idProduct}=="1556", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0666"
  '';
}
