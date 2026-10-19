{ ... }:

{
  # installs qt5ct and qt6ct, sets QT_QPA_PLATFORMTHEME=qt5ct and the plugin path,
  # qt6ct answers to qt5ct too, so qt5 and qt6 apps both get the theme
  qt = {
    enable = true;
    platformTheme = "qt5ct";
  };

  # plain config files, paths inside them point at /etc/xdg/qt6ct
  environment.etc."xdg/qt6ct".source = ./qt6ct;

  # qt5ct and qt6ct only read ~/.config, so link the conf there
  systemd.user.tmpfiles.rules = [
    "d %h/.config/qt6ct - - - -"
    "d %h/.config/qt5ct - - - -"
    "L+ %h/.config/qt6ct/qt6ct.conf - - - - /etc/xdg/qt6ct/qt6ct.conf"
    "L+ %h/.config/qt5ct/qt5ct.conf - - - - /etc/xdg/qt6ct/qt6ct.conf"
  ];
}
