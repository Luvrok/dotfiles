# keymaps/ holds the layer layouts for keymap-drawer.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.galaxy.hardware.qmk.enable = lib.mkEnableOption "QMK/VIA keyboard tools";

  config = lib.mkIf config.galaxy.hardware.qmk.enable {
    hardware.keyboard.qmk.enable = true;

    environment.systemPackages = with pkgs; [
      qmk
      vial
      via
      keymap-drawer
    ];

    services.udev.extraRules = ''
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="cb10", ATTRS{idProduct}=="1556", MODE="0660", GROUP="users", TAG+="uaccess", TAG+="udev-acl"
      KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0666"
    '';
  };
}
