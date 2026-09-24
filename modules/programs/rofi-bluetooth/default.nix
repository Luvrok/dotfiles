{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.galaxy.programs.rofi-bluetooth.enable = lib.mkEnableOption "the rofi bluetooth menu";

  config = lib.mkIf config.galaxy.programs.rofi-bluetooth.enable {
    environment.systemPackages = [
      (config.galaxy.lib.mkScript pkgs {
        name = "rofi-bluetooth";
        src = ./rofi-bluetooth;
        excludeShellChecks = [ "SC2086" ];
        runtimeInputs = with pkgs; [
          rofi
          bluez
          bc
          util-linux
          libnotify
          gnused
        ];
      })
    ];
  };
}
