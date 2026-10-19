{ config, lib, ... }:
let
  cfg = config.services.rgb-off;
  openrgb = lib.getExe' config.services.hardware.openrgb.package "openrgb";
in
{
  options.services.rgb-off = {
    enable = lib.mkEnableOption "turning off rgb at boot with openrgb";

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
    # keep the module for udev rules and i2c modules
    services.hardware.openrgb = {
      enable = true;
      motherboard = lib.mkDefault "amd";
    };

    # server state breaks mystic light writes, so no server
    systemd.services.openrgb.enable = false;

    systemd.services.rgb-off = {
      description = "turn off rgb";
      wantedBy = [ "multi-user.target" ];
      serviceConfig = {
        Type = "oneshot";
        # same config dir as the sudo tests, zone sizes live there
        Environment = "HOME=/root";
        ExecStart = "${openrgb} --noautoconnect ${lib.concatStringsSep " " cfg.devices}";
      };
    };
  };
}
