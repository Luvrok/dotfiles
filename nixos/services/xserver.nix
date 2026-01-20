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
      WALLPAPER=~/HOME/wizzard/wallpaper/elden-ring--1.jpg
      ${pkgs.xwallpaper}/bin/xwallpaper --zoom $WALLPAPER

      export PATH=/home/${username}/.local/bin:$PATH
      dwmblocks &
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
