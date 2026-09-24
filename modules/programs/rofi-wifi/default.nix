{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.galaxy.programs.rofi-wifi.enable = lib.mkEnableOption "the rofi wifi menu (iwd)" // {
    default = config.galaxy.network.wifi.enable && config.galaxy.programs.rofi.enable;
    defaultText = "wifi (iwd) and rofi are enabled";
  };

  config = lib.mkIf config.galaxy.programs.rofi-wifi.enable {
    environment.systemPackages = [
      (config.galaxy.lib.mkScript pkgs {
        name = "rofi-wifi";
        src = ./rofi-wifi;
        runtimeInputs = with pkgs; [
          rofi
          iwd
          libnotify
          gnused
          gawk
        ];
      })
    ];
  };
}
