{
  config,
  pkgs,
  ...
}:

let
  monitorLayout =
    if config.networking.hostName == "barnard" then ''
      ${pkgs.xrandr}/bin/xrandr --output DisplayPort-1 --primary --mode 2560x1440 --rate 120
      ${pkgs.xrandr}/bin/xrandr --output DisplayPort-0 --mode 2560x1440 --rate 120 --left-of DisplayPort-1
    ''
    else if config.networking.hostName == "dash" then ''
      ${pkgs.xrandr}/bin/xrandr --output eDP-1 --primary --auto
    ''
    else "";
in
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
    startx.enable = false;
    sessionCommands = ''
      ${monitorLayout}

      W="$HOME/HOME/wizzard/wallpaper/art/nature/Church_Heart_of_the_Andes.jpg"
      [ -f "$W" ] && ${pkgs.xwallpaper}/bin/xwallpaper --zoom "$W" || true

      ${pkgs.xidlehook}/bin/xidlehook \
        --not-when-fullscreen --not-when-audio \
        --timer 300 "${pkgs.xset}/bin/xset dpms force off" \
                    "${pkgs.xset}/bin/xset dpms force on" &

      dwmblocks &
    '';
  };

  serverFlagsSection = ''
    Option "BlankTime" "0"
    Option "StandbyTime" "0"
    Option "SuspendTime" "0"
    Option "OffTime" "0"
  '';
}
