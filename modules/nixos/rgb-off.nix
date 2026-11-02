{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.rgb-off;
  openrgb = lib.getExe' pkgs.openrgb "openrgb";
in
{
  options.services.rgb-off = {
    enable = lib.mkEnableOption "turning off rgb after boot with openrgb";

    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        # msi board ignores black, only brightness 0 kills it
        "-d B650 -m Static -c 000000 -b 0"
        # ram sticks, indexes from `openrgb -l`
        "-d 0 -m Off"
        "-d 1 -m Off"
      ];
      description = "openrgb args per device, all run in one detection pass";
    };
  };

  config = lib.mkIf cfg.enable {
    # not services.hardware.openrgb: its udev rules (~5700 lines, 70% of all
    # rules) slowed udev at boot, the greeter's keyboard came seconds late.
    # they only let a user run openrgb without root, rgb-off runs as root
    # and openrgb by hand is with sudo. what's left of the module: the
    # package and the i2c modules for the ram sticks (smbus on amd)
    environment.systemPackages = [ pkgs.openrgb ];
    boot.kernelModules = [
      "i2c-dev"
      "i2c-piix4"
    ];

    systemd.services.rgb-off = {
      description = "turn off rgb";
      serviceConfig = {
        Type = "oneshot";
        # same config dir as the sudo tests, zone sizes live there
        Environment = "HOME=/root";
        ExecStart = "${openrgb} --noautoconnect ${lib.concatStringsSep " " cfg.devices}";
      };
    };

    # nothing waits for it: 30 s after boot, off the boot's way
    systemd.timers.rgb-off = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnBootSec = "30s";
    };
  };
}
