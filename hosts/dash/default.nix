{ ... }:

{
  dotfiles.hyprland.enable = true;

  # the gpu driver and the font size of the desktop (modules/nixos/desktop)
  videoDrivers = [ "nvidia" ];
  fontSize = 14;

  environment.sessionVariables = {
    XFT_DPI = "192";

    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_SCALE_FACTOR = "1";
    QT_SCREEN_SCALE_FACTORS = "2;2";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };
}
