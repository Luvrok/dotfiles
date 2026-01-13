{ config, pkgs, lib, ... }:

{
  boot = {
    loader = {
      timeout = lib.mkDefault 3;

      systemd-boot = {
        enable = true;
        editor = lib.mkDefault false;
        consoleMode = lib.mkDefault "max";
        configurationLimit = lib.mkDefault 10;
      };

      efi.canTouchEfiVariables = lib.mkDefault true;
      grub.enable = lib.mkForce false;
    };

    kernelParams = [
      "quiet"
    ];

    tmp.cleanOnBoot = lib.mkDefault true;
  };
}

