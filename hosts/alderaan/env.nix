{ ... }:

{
  imports = [
    ../../nixos/config/alderaan.nix
  ];

  environment.sessionVariables = {
    XFT_DPI = "192";

    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_SCALE_FACTOR = "1";
    QT_SCREEN_SCALE_FACTORS = "2;2";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };
}
