{ pkgs, ... }:

{
  programs.mpv.enable = true;
  xdg.configFile."mpv".source = pkgs.mpv-config;
}
