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

    tmp.cleanOnBoot = lib.mkDefault true;

    # no boot text on the console: the greeter is on tty1, its lines show
    # when weston goes away at login. errors are in journalctl
    consoleLogLevel = 3;
    kernelParams = [
      "quiet"
      "systemd.show_status=false"
      "rd.systemd.show_status=false"
      "udev.log_level=3"
      "rd.udev.log_level=3"
    ];
  };
}
