# hyprland: the desktop session. the bar, the wallpaper, the notifications
# and the menus are quickshell. modules/nixos/desktop imports this
{
  config,
  lib,
  pkgs,
  pkgs-hypr,
  ...
}:

let
  cfg = config.dotfiles.hyprland;
in
{
  options.dotfiles.hyprland.enable = lib.mkEnableOption "the hyprland session with its quickshell";

  config = lib.mkIf cfg.enable {
    services.displayManager.defaultSession = "hyprland";

    # from nixpkgs-hypr, the snapshot this desktop is tested on (flake.nix):
    # a nixpkgs update must not move the compositor, the shell or the portal
    # out from under the config
    programs.hyprland = {
      enable = true;
      package = pkgs-hypr.hyprland;
      portalPackage = pkgs-hypr.xdg-desktop-portal-hyprland;
    };

    # the compositor loads the gpu driver from /run/opengl-driver, and its
    # libgbm and the driver have to be one mesa: both from the snapshot
    hardware.graphics = {
      package = pkgs-hypr.mesa;
      package32 = pkgs-hypr.pkgsi686Linux.mesa;
    };

    # both look in XDG_CONFIG_DIRS (/etc/xdg) after ~/.config: hyprland for
    # hypr/hyprland.lua, quickshell for quickshell/<name> (qs -c hyprland).
    # hyprland checks its config while the system builds, so an update that
    # changes the lua api fails nixos-rebuild, not the next login
    environment.etc."xdg/hypr/hyprland.lua".source = pkgs.runCommand "hyprland.lua" { } ''
      mkdir run
      XDG_RUNTIME_DIR=$PWD/run HOME=$PWD \
        ${config.programs.hyprland.package}/bin/Hyprland --verify-config -c ${./hyprland.lua} --i-am-really-stupid
      cp ${./hyprland.lua} $out
    '';
    # the quickshell config, with what the host has on (Features.qml) written
    # in. jarvis off: its menu, bar icon and key stay in the code and do
    # nothing, and its line is gone from the keys menu
    environment.etc."xdg/quickshell/hyprland".source =
      pkgs.runCommand "quickshell-hyprland" { } ''
        cp -r ${./quickshell} $out
        chmod -R u+w $out
        cat > $out/Features.qml <<'EOF'
        pragma Singleton

        import QtQuick

        QtObject {
            readonly property bool jarvis: ${lib.boolToString config.services.jarvis.enable}
        }
        EOF
        ${lib.optionalString (!config.services.jarvis.enable) ''
          sed -i '/^ *mod+ctrl+j  *jarvis$/d' $out/keys.conf
        ''}
      '';
    # jarvis' menu and bar icon (Luvrok/jarvis): its build checks them (no
    # rounded shapes) while services.jarvis is enabled
    services.jarvis.ui.qmlFiles = [
      ./quickshell/menus/Jarvis.qml
      ./quickshell/widgets/MicTile.qml
      ./quickshell/widgets/JarvisBar.qml
    ];
    # the lock screen's password (quickshell/Lock.qml, PamContext "quickshell")
    security.pam.services.quickshell = { };

    # the run menu's xray mode (tab): an app through xray
    environment.etc."proxychains-xray.conf".source = ./proxychains.conf;

    environment.systemPackages = with pkgs; [
      # the shell too: its qml api changes with the compositor's, same pin
      pkgs-hypr.quickshell
      # askpass for sudo -A and ssh, the quickshell menu answers it
      (writeShellApplication {
        name = "hypr-askpass";
        runtimeInputs = [ quickshell ];
        text = builtins.readFile ./quickshell/scripts/askpass;
      })
      # rofi -dmenu for scripts, the librewolf tab switcher's host uses it
      # (modules/home/programs/librewolf)
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
      # pinentry for gpg-agent, the same menu. modules/home/programs/gpg.nix picks it
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

      # started from hyprland.lua
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

    # hyprland.lua starts and stops it. hyprland ships the same unit now
    # (share/systemd/user), but nixpkgs doesn't install systemd.packages for
    # it, so this one is the installed one: keep it equal to the package's,
    # PropagatesStopTo included
    systemd.user.targets.hyprland-session = {
      description = "hyprland compositor session";
      documentation = [ "man:systemd.special(7)" ];
      bindsTo = [ "graphical-session.target" ];
      wants = [ "graphical-session-pre.target" ];
      after = [ "graphical-session-pre.target" ];
      unitConfig.PropagatesStopTo = [ "graphical-session.target" ];
    };

    # gtk on wayland takes theme, icons, font and cursor from dconf through the
    # settings portal and skips settings.ini, so the same as modules/nixos/gtk's
    # settings.ini goes here. locked: a value in the user db (home-manager's old
    # gtk module left gtk-theme=gruvbox-dark there, a theme that's gone) would
    # win otherwise
    programs.dconf.profiles.user.databases = [
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
  };
}
