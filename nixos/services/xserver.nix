{
  config,
  pkgs,
  username,
  ...
}:

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
      WALLPAPER="$HOME/HOME/wizzard/wallpaper/art/nature/Church_Heart_of_the_Andes.jpg"
      ${pkgs.xwallpaper}/bin/xwallpaper --zoom "$WALLPAPER"

      export PATH=/home/${username}/.local/bin:$PATH
      dwmblocks &
    '';
  };

  serverFlagsSection = ''
    Option "DPMS" "true"
    Option "BlankTime"  "20"
    Option "StandbyTime" "30"
    Option "SuspendTime" "40"
    Option "OffTime"     "50"
  '';
}
