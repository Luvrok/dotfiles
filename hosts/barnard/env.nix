{ lib, pkgs, ... }:

{
  imports = [
    ../../nixos/config/barnard.nix
    ./xray.nix
    # docs index for pi, vectors from llama-swap
    ../../nixos/services/docs-mcp
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

  # the sddm greeter runs in weston: only the main monitor on the right (DP-2),
  # the left one (DP-1) stays off until the session starts. kiosk is the
  # shell the sddm module uses
  services.displayManager.sddm.wayland.compositorCommand =
    let
      ini = (pkgs.formats.ini { }).generate "weston.ini" {
        keyboard = {
          keymap_layout = "us,ru";
          keymap_options = "grp:win_space_toggle";
        };
        output = {
          name = "DP-1";
          mode = "off";
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
