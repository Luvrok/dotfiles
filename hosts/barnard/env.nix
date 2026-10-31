{ ... }:

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
