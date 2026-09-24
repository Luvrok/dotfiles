{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.galaxy.programs.rofi-recording.enable = lib.mkEnableOption "the rofi screen recorder";

  config = lib.mkIf config.galaxy.programs.rofi-recording.enable {
    environment.systemPackages = [
      (config.galaxy.lib.mkScript pkgs {
        name = "rofi-recording";
        src = ./rofi-recording;
        excludeShellChecks = [ "SC2034" ];
        runtimeInputs = with pkgs; [
          rofi
          ffmpeg-full
          slop
          xrandr
          xdpyinfo
          pulseaudio
          wireplumber
          procps
          libnotify
          gawk
          gnused
        ];
      })
    ];
  };
}
