# Toggle an ffplay window with the Android phone webcam (v4l2) in the corner.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.galaxy.programs.webcam.enable = lib.mkEnableOption "the webcam toggle";

  config = lib.mkIf config.galaxy.programs.webcam.enable {
    environment.systemPackages = [
      (config.galaxy.lib.mkScript pkgs {
        name = "webcam";
        src = ./webcam;
        runtimeInputs = with pkgs; [
          ffmpeg-full
          xdpyinfo
          gawk
          libnotify
        ];
      })
    ];
  };
}
