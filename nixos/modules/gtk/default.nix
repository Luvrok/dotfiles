{ lib, pkgs, ... }:

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

  # gtk on wayland (sway) takes these from dconf through the settings portal
  # and skips settings.ini, keep them the same. x11 gtk3 doesn't read them
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        gtk-theme = "gruvbox-flat";
        icon-theme = "Gruvbox-Plus-Dark";
        font-name = "JetBrainsMonoNL Nerd Font Propo 10";
        # home.pointerCursor, x11 gets it from there
        cursor-theme = "Vanilla-DMZ";
        cursor-size = lib.gvariant.mkInt32 32;
      };
    }
  ];

  # themes are looked up in ~/.local/share, link it there
  systemd.user.tmpfiles.rules = [
    "d %h/.local/share/themes - - - -"
    "L+ %h/.local/share/themes/gruvbox-flat - - - - /etc/gtk/gruvbox-flat"
  ];
}
