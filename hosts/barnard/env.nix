{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../../nixos/config/barnard.nix
    ./xray.nix
    # docs index for pi, vectors from llama-swap
    ../../nixos/services/docs-mcp
    # the obsidian vault, its own index next to it
    ../../nixos/services/notes-mcp
    # the wayland sessions
    ../../nixos/services/sway
    ../../nixos/services/hyprland
    # the movies and series of /media/outer-1, played in mpv
    ../../nixos/services/kodi
    # their downloads: radarr, sonarr, qbittorrent, subtitles
    ../../nixos/services/arr
    # api keys of opencode's free tiers
    ../../nixos/services/opencode-keys.nix
  ];

  # the voice assistant (Luvrok/jarvis): its models in llama-swap's
  # config.yaml, its menu in quickshell (hyprland's default.nix checks it)
  services.jarvis = {
    enable = true;
    # the hub's lfs cdn and docker hub need xray's mixed inbound
    proxy = lib.mkIf config.services.xray.enable "http://127.0.0.1:10808";
    # the notes' own docs-mcp-server (nixos/services/notes-mcp)
    tools.notesMcp = "http://127.0.0.1:6281/mcp";
  };

  # the sddm greeter runs in weston, on the first output: DP-1, the main one
  # on the right. us,ru like the sessions, the theme's color under it.
  # kiosk is the shell the sddm module uses
  services.displayManager.sddm.wayland.compositorCommand =
    let
      ini = (pkgs.formats.ini { }).generate "weston.ini" {
        shell.background-color = "0xff171717";
        keyboard = {
          keymap_layout = "us,ru";
          keymap_options = "grp:win_space_toggle";
        };
      };
    in
    "${lib.getExe pkgs.weston} --shell=kiosk -c ${ini}";

  environment.sessionVariables = {
    XFT_DPI = "109";
    XCURSOR_THEME = "Vanilla-DMZ";
    XCURSOR_SIZE = "32";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  environment.extraInit = ''
    #Turn off gui for ssh auth
    unset -v SSH_ASKPASS
  '';
}
