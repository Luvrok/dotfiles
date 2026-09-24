{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.galaxy.programs.rofi-audio.enable = lib.mkEnableOption "the rofi audio output switcher";

  config = lib.mkIf config.galaxy.programs.rofi-audio.enable {
    environment.systemPackages = [
      (config.galaxy.lib.mkScript pkgs {
        name = "rofi-audio";
        src = ./rofi-audio;
        excludeShellChecks = [
          "SC2086"
          "SC2126"
        ];
        runtimeInputs = with pkgs; [
          rofi
          wireplumber
          gnugrep
          gnused
          coreutils
          findutils
        ];
      })
    ];
  };
}
