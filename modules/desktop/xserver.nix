{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.galaxy.desktop.xserver;
  host = config.galaxy.host;

  xrandr = "${pkgs.xrandr}/bin/xrandr";

  monitorLayout = lib.concatMapStrings (
    m:
    lib.concatStringsSep " " (
      [
        xrandr
        "--output"
        m.output
      ]
      ++ lib.optional m.primary "--primary"
      ++ (if m.mode == null then [ "--auto" ] else [ "--mode ${m.mode}" ])
      ++ lib.optional (m.rate != null) "--rate ${toString m.rate}"
      ++ lib.optional (m.leftOf != null) "--left-of ${m.leftOf}"
    )
    + "\n"
  ) host.monitors;
in
{
  options.galaxy.desktop.xserver = {
    enable = lib.mkEnableOption "X11";

    monitorConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Monitor sections for xorg.conf.d/60-monitor.conf.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.xserver = {
      enable = true;
      upscaleDefaultCursor = true;
      logFile = null;

      videoDrivers =
        {
          amd = [ "amdgpu" ];
          nvidia = [ "nvidia" ];
        }
        .${host.gpu} or [ ];
      dpi = host.xftDpi;

      xkb = {
        variant = "";
        options = "";
        layout = "us,ru";
      };

      displayManager = {
        startx.enable = false;
        sessionCommands = lib.mkBefore ''
          ${monitorLayout}
          W="$HOME/HOME/wizzard/wallpaper/art/nature/Church_Heart_of_the_Andes.jpg"
          [ -f "$W" ] && ${pkgs.xwallpaper}/bin/xwallpaper --zoom "$W" || true

          ${pkgs.xidlehook}/bin/xidlehook \
            --not-when-fullscreen --not-when-audio \
            --timer 300 "${pkgs.xset}/bin/xset dpms force off" \
                        "${pkgs.xset}/bin/xset dpms force on" &
        '';
      };

      serverFlagsSection = ''
        Option "BlankTime" "0"
        Option "StandbyTime" "0"
        Option "SuspendTime" "0"
        Option "OffTime" "0"
      '';
    };

    environment.etc = {
      "X11/xorg.conf.d/00-keyboard.conf".text = ''
        Section "InputClass"
          Identifier "system-keyboard"
          MatchIsKeyboard "on"
          Option "XkbLayout" "us,ru"
          Option "XkbOptions" "grp:win_space_toggle"
        EndSection
      '';

      "X11/xorg.conf.d/60-monitor.conf" = lib.mkIf (cfg.monitorConfig != "") {
        text = cfg.monitorConfig;
      };

      "X11/xorg.conf.d/50-touchpad.conf" = lib.mkIf host.isLaptop {
        text = ''
          Section "InputClass"
            Identifier "touchpad"
            Driver "libinput"
            MatchIsTouchpad "on"
            Option "Tapping" "on"
            Option "AccelSpeed" "0.7"
            Option "NaturalScrolling" "false"
          EndSection
        '';
      };
    };

    home-manager.users.${host.user}.home.file.".Xmodmap".text = ''
      keycode  37 = Control_L NoSymbol Control_L
      keycode  50 = Shift_L NoSymbol Shift_L
    '';
  };
}
