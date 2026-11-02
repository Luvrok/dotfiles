{ pkgs, ... }:

{
  programs.mpv = {
    enable = true;
    # the keys are in nixos/overlays/mpv/input.conf, the settings in
    # mpv-config's script-opts
    scripts = with pkgs.mpvScripts; [
      # the hyprland bar and player menu see it (quickshell's Media.qml)
      mpris
      # c: cut a clip out of what's playing
      videoclip
      # >: skip an opening or ending, it only prompts on its own
      eisa01.smartskip
      # n: sync subtitles to the audio
      autosubsync-mpv
      # r: reopen at the same spot, stuck streams by itself
      reload
      # ctrl+o / ctrl+i: back and forth between seeks, like vim's jumplist
      eisa01.undoredo
      # /: search the subtitle lines and jump to one
      mpv-subtitle-lines
    ];
  };
  xdg.configFile."mpv".source = pkgs.mpv-config;
}
