# hyprland: the twin of the sway session on hyprland's own layouts and
# dispatchers, with animations. the bar, the wallpaper and the menus that do
# what the rofi scripts do are quickshell. sddm lists it next to sway, it's
# the default session. barnard only, its env.nix imports this
{
  config,
  lib,
  pkgs,
  ...
}:

{
  programs.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };

  # both look in XDG_CONFIG_DIRS (/etc/xdg) after ~/.config: hyprland for
  # hypr/hyprland.lua, quickshell for quickshell/<name> (qs -c hyprland).
  # hyprland checks its config while the system builds, so an update that
  # changes the lua api fails nixos-rebuild, not the next login
  environment.etc."xdg/hypr/hyprland.lua".source =
    pkgs.runCommand "hyprland.lua" { } ''
      mkdir run
      XDG_RUNTIME_DIR=$PWD/run HOME=$PWD \
        ${config.programs.hyprland.package}/bin/Hyprland --verify-config -c ${./hyprland.lua} --i-am-really-stupid
      cp ${./hyprland.lua} $out
    '';
  environment.etc."xdg/quickshell/hyprland".source = ./quickshell;
  # the lock screen's password (quickshell/Lock.qml, PamContext "quickshell")
  security.pam.services.quickshell = { };

  # the run menu's xray mode (tab): an app through xray
  environment.etc."proxychains-xray.conf".source = ./proxychains.conf;

  environment.systemPackages = with pkgs; [
    quickshell
    # askpass for sudo -A and ssh, the quickshell menu answers it
    (writeShellApplication {
      name = "hypr-askpass";
      runtimeInputs = [ quickshell ];
      text = builtins.readFile ./quickshell/scripts/askpass;
    })
    # rofi -dmenu for scripts, the librewolf tab switcher's host uses it
    # while quickshell runs (home/programs/librewolf)
    (writeShellApplication {
      name = "hypr-dmenu";
      runtimeInputs = [
        quickshell
        coreutils
        gnused
      ];
      text = builtins.readFile ./quickshell/scripts/dmenu;
    })
    # "save as" through the file chooser portal (termfilechooser), the
    # screenshot's shift+s
    (writers.writePython3Bin "hypr-savefile" {
      libraries = [ python3Packages.jeepney ];
    } (builtins.readFile ./quickshell/scripts/savefile))
    # pinentry for gpg-agent, the same menu. home/programs/gpg.nix picks it
    # while quickshell runs
    (writeShellApplication {
      name = "hypr-pinentry";
      # gpg-agent may start it with a bare PATH
      runtimeInputs = [
        quickshell
        coreutils
      ];
      text = builtins.readFile ./quickshell/scripts/pinentry;
    })

    # started from hyprland.lua, the same tools as in sway
    swayidle
    sway-audio-idle-inhibit
    gammastep
    wl-clipboard
    cliphist
    grim
    slurp

    # quickshell/scripts: record, bt-pair, wifi, apps and route (pw-dump,
    # pw-link)
    pipewire
    wf-recorder
    wlr-randr
    expect
    jq
    iproute2
    hyprprop
    # pass types the login with it
    wtype
    # the player's visualizer
    cava
    # the run menu's alt+enter
    proxychains-ng
    # the tools menu: color picker, calc, the emoji's names
    hyprpicker
    libqalculate
    unicode-emoji
  ];

  # the emoji menu reads /run/current-system/sw/share/unicode/emoji
  environment.pathsToLink = [ "/share/unicode" ];

  # hyprland.lua starts and stops it, like sway-session.target in the sway module
  systemd.user.targets.hyprland-session = {
    description = "hyprland compositor session";
    documentation = [ "man:systemd.special(7)" ];
    bindsTo = [ "graphical-session.target" ];
    wants = [ "graphical-session-pre.target" ];
    after = [ "graphical-session-pre.target" ];
  };

  # quickshell is the notification server here (quickshell/Notifs.qml). dunst
  # (home/services/dunst.nix) starts on the first notification over d-bus,
  # so it stays off while a hyprland runs. sway still gets it
  systemd.user.units."dunst.service" = {
    overrideStrategy = "asDropin";
    text = ''
      [Service]
      ExecCondition=${pkgs.writeShellScript "dunst-not-in-hyprland" ''
        lock=$XDG_RUNTIME_DIR/hypr/''${HYPRLAND_INSTANCE_SIGNATURE:-none}/hyprland.lock
        read -r pid 2>/dev/null <"$lock" && kill -0 "$pid" 2>/dev/null && exit 1
        exit 0
      ''}
    '';
  };

  # gtk on wayland reads theme, icons, font and cursor from dconf, like in
  # the sway module (locked like there). it's there already when sway is on
  programs.dconf.profiles.user.databases = lib.mkIf (!config.programs.sway.enable) [
    {
      lockAll = true;
      settings."org/gnome/desktop/interface" = {
        gtk-theme = "gruvbox-flat";
        icon-theme = "Gruvbox-Plus-Dark";
        font-name = "JetBrainsMonoNL Nerd Font Propo 10";
        cursor-theme = "Vanilla-DMZ";
        cursor-size = lib.gvariant.mkInt32 32;
      };
    }
  ];
}
