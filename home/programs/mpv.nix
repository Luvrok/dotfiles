{ pkgs, ... }:

{
  programs.mpv = {
    enable = true;
    # mpris: the hyprland bar and player menu see it (quickshell's Media.qml)
    scripts = [ pkgs.mpvScripts.mpris ];
  };
  xdg.configFile."mpv".source = pkgs.mpv-config;
}
