{ config, lib, ... }:

{
  options.galaxy.desktop.sway.enable = lib.mkEnableOption "sway as an extra session next to dwm";

  config = lib.mkIf config.galaxy.desktop.sway.enable {
    programs.sway.enable = true;
  };
}
