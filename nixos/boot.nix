{ lib, ... }:

{
  boot = {
    loader = {
      timeout = lib.mkDefault 3;

      systemd-boot = {
        enable = true;
        editor = lib.mkDefault false;
        consoleMode = lib.mkDefault "max";
        configurationLimit = lib.mkDefault 20;
      };

      efi.canTouchEfiVariables = lib.mkDefault true;
      grub.enable = lib.mkForce false;
    };

    kernelParams = [
      "quiet"
      "loglevel=3"
    ];

    tmp.cleanOnBoot = lib.mkDefault true;
  };
}
