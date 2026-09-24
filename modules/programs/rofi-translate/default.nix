{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.galaxy.programs.rofi-translate.enable =
    lib.mkEnableOption "the rofi translator (LibreTranslate on jedha, translate-shell)";

  config = lib.mkIf config.galaxy.programs.rofi-translate.enable {
    environment.systemPackages = [
      (config.galaxy.lib.mkScript pkgs {
        name = "rofi-translate";
        src = ./rofi-translate;
        runtimeInputs = with pkgs; [
          rofi
          translate-shell
          jq
          curl
          xclip
          libnotify
          gawk
          gnused
        ];
      })
    ];
  };
}
