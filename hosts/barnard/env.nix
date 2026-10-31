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

  # the sddm greeter runs in weston. it focuses the first output weston
  # announces, that's DP-1 on the left, and weston can't pick another one
  # (a clone left the right one black). so DP-1 is off in the greeter only,
  # hyprland turns it on (hyprland.lua). kiosk is the shell the sddm module uses
  services.displayManager.sddm.wayland.compositorCommand =
    let
      ini = (pkgs.formats.ini { }).generate "weston.ini" {
        # what shows before the greeter is up, the theme's color. kiosk is
        # black without it
        shell.background-color = "0xff171717";
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
