{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.galaxy.boot;
in
{
  options.galaxy.boot = {
    systemdBoot.enable = lib.mkEnableOption "systemd-boot on EFI (otherwise the NixOS default, grub)";

    # Issue: kernel panic "BUG at mm/vmalloc.c:3167" occurring ~once a week since last year, sometimes more often.
    # Context: AMD + amdgpu with dual-monitor setup (both 120 Hz); may be related (see forum thread).
    # Best solution yet: pin the Linux 6.12 kernel.
    # Ref: https://bbs.archlinux.org/viewtopic.php?id=306587
    pinKernel = lib.mkEnableOption "the pinned 6.12 kernel";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.systemdBoot.enable {
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
      };
    })

    (lib.mkIf cfg.pinKernel {
      boot.kernelPackages = pkgs.linuxPackages_6_12;
    })
  ];
}
