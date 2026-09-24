{ config, lib, ... }:

{
  options.galaxy.security.desktop.enable =
    lib.mkEnableOption "rtkit, polkit and relaxed sudo for a desktop";

  config = lib.mkIf config.galaxy.security.desktop.enable {
    security.rtkit.enable = true; # PipeWire for screen capture
    security.polkit.enable = true;

    security.sudo.extraConfig = ''
      Defaults lecture = never
      Defaults timestamp_timeout=450
    '';
  };
}
