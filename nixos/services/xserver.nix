{ config, pkgs, username, ... }:

{
  enable = true;
  upscaleDefaultCursor = true;
  logFile = null;

  videoDrivers = config.videoDrivers;
  dpi = config.dpi;

  xkb = {
    variant = "";
    options = "";
    layout = "us,ru";
  };

  windowManager.dwm = {
    enable = true;
    package = pkgs.dwm;
  };

  displayManager = {
    startx.enable = true;
    sessionCommands = ''
      WALLPAPER=/home/${username}/HOME/wizzard/wallpaper/elden-ring--1.jpg
      feh --geometry 2560x1440+0+0 --auto-zoom --bg-fill "$WALLPAPER"

      export PATH=/home/${username}/.local/bin/sh-others:/home/${username}/.local/bin/sh-rofi:/home/${username}/.local/bin/sh-nixos:$PATH
      xset -dpms &
      greenclip daemon &
    '';
  };

  serverFlagsSection = ''
    Option "DPMS" "true"
    Option "BlankTime"  "5"
    Option "StandbyTime" "10"
    Option "SuspendTime" "15"
    Option "OffTime"     "20"
  '';
}
