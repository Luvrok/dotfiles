# hyprland: the twin of the sway session on hyprland's own layouts and
# dispatchers, animations like picom in i3. the bar, the wallpaper and the
# menus that do what the rofi scripts do are quickshell. sddm lists it next
# to i3 and sway, i3 stays the default. barnard only, its env.nix imports this
{
  config,
  lib,
  pkgs,
  ...
}:

let
  # nixpkgs without the overlays: the dmenu fork in nixos/overlays changes
  # uwsm, hyprland's uwsm session file points to it, so that hyprland isn't
  # in the binary cache and builds from source
  stock = import pkgs.path { inherit (pkgs.stdenv.hostPlatform) system; };
in
{
  programs.hyprland = {
    enable = true;
    package = stock.hyprland;
    portalPackage = stock.xdg-desktop-portal-hyprland;
  };

  # both look in XDG_CONFIG_DIRS (/etc/xdg) after ~/.config: hyprland for
  # hypr/hyprland.lua, quickshell for quickshell/<name> (qs -c hyprland)
  environment.etc."xdg/hypr/hyprland.lua".source = ./hyprland.lua;
  environment.etc."xdg/quickshell/hyprland".source = ./quickshell;

  environment.systemPackages = with pkgs; [
    quickshell
    # askpass for sudo -A and ssh, the quickshell menu answers it
    (writeShellApplication {
      name = "hypr-askpass";
      runtimeInputs = [ quickshell ];
      text = builtins.readFile ./quickshell/scripts/askpass;
    })

    # started from hyprland.lua, the same tools as in sway
    swayidle # xidlehook
    sway-audio-idle-inhibit # xidlehook --not-when-audio
    gammastep # redshift
    wl-clipboard # xclip
    cliphist # greenclip
    grim # flameshot
    slurp

    # quickshell/scripts: record and bt-pair
    wf-recorder
    expect
    jq
  ];

  # hyprland.lua starts and stops it, like sway-session.target in the sway module
  systemd.user.targets.hyprland-session = {
    description = "hyprland compositor session";
    documentation = [ "man:systemd.special(7)" ];
    bindsTo = [ "graphical-session.target" ];
    wants = [ "graphical-session-pre.target" ];
    after = [ "graphical-session-pre.target" ];
  };

  # hyprland-portals.conf replaces portals.conf under hyprland, so the
  # hyprland package's defaults and the file picker (yazi, xdg module) go here
  xdg.portal.config.hyprland = {
    default = [
      "hyprland"
      "gtk"
    ];
    "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
  };

  # gtk on wayland reads theme, icons, font and cursor from dconf, like in
  # the sway module. it's there already when sway is on
  programs.dconf.profiles.user.databases = lib.mkIf (!config.programs.sway.enable) [
    {
      settings."org/gnome/desktop/interface" = {
        gtk-theme = "gruvbox-flat";
        icon-theme = "Gruvbox-Plus-Dark";
        font-name = "JetBrainsMonoNL Nerd Font Propo 10";
        cursor-theme = "Vanilla-DMZ";
        cursor-size = lib.gvariant.mkInt32 32;
      };
    }
  ];

  # the hyprland module turns it on, then i3 starts xdg autostart files too
  services.xserver.desktopManager.runXdgAutostartIfNone = false;
}
