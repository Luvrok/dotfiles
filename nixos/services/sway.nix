{ pkgs, ... }:

{
  programs.sway = {
    enable = true;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
    export SDL_VIDEODRIVER = wayland
    export QT_QPA_PLATFORM = wayland
    export XDG_SESSION_TYPE = wayland
    '';
  };

  environment.systemPackages = with pkgs; [
    wl-mirror
    wl-clipboard
  ];
}
