{ pkgs, ... }:

{
  # icon theme for gtk and qt, gold folders like gruvbox yellow
  environment.systemPackages = [
    (pkgs.gruvbox-plus-icons.override { folder-color = "gold"; })
  ];

  environment.etc = {
    # gtk reads settings.ini from /etc/xdg on its own
    "xdg/gtk-3.0/settings.ini".source = ./settings.ini;
    # thunar defaults: list view, small icons
    "xdg/xfce4/xfconf/xfce-perchannel-xml/thunar.xml".source = ./xfconf/thunar.xml;
    "gtk/gruvbox-flat".source = ./theme;
  };

  # themes are looked up in ~/.local/share, link it there
  systemd.user.tmpfiles.rules = [
    "d %h/.local/share/themes - - - -"
    "L+ %h/.local/share/themes/gruvbox-flat - - - - /etc/gtk/gruvbox-flat"
  ];
}
