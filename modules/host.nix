{ config, lib, ... }:

let
  inherit (lib) mkOption types;
  cfg = config.galaxy.host;

  monitor = types.submodule {
    options = {
      output = mkOption { type = types.str; };
      mode = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "null means --auto.";
      };
      rate = mkOption {
        type = types.nullOr types.int;
        default = null;
      };
      primary = mkOption {
        type = types.bool;
        default = false;
      };
      leftOf = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      greeter = mkOption {
        type = types.bool;
        default = true;
        description = "false turns the output off on the login screen.";
      };
    };
  };
in
{
  options.galaxy.host = {
    user = mkOption {
      type = types.str;
      default = config.networking.hostName;
      description = "Main login user.";
    };

    gpu = mkOption {
      type = types.nullOr (
        types.enum [
          "amd"
          "nvidia"
        ]
      );
      default = null;
    };

    dpi = mkOption {
      type = types.enum [
        "low"
        "high"
      ];
      default = "low";
    };

    xftDpi = mkOption {
      type = types.int;
      default = if cfg.dpi == "high" then 192 else 109;
    };

    fontSize = mkOption {
      type = types.int;
      default = if cfg.dpi == "high" then 14 else 11;
    };

    isLaptop = mkOption {
      type = types.bool;
      default = false;
    };

    monitors = mkOption {
      type = types.listOf monitor;
      default = [ ];
      description = "Applied with xrandr at X session start, in this order.";
    };

    sshKeys = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Keys allowed to log in as root and as the main user.";
    };
  };
}
