# Everything a desktop session needs that no single program owns:
# locale, console, portals, system services, GTK/Qt look, default apps.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.galaxy.host) user dpi xftDpi;
  c = config.galaxy.theme.colors;
  hex = lib.removePrefix "#";
in
{
  options.galaxy.desktop.session.enable = lib.mkEnableOption "the desktop session base";

  config = lib.mkIf config.galaxy.desktop.session.enable {
    i18n = {
      defaultLocale = "en_US.UTF-8";
      extraLocaleSettings = {
        LC_ADDRESS = "ru_RU.UTF-8";
        LC_IDENTIFICATION = "ru_RU.UTF-8";
        LC_MEASUREMENT = "ru_RU.UTF-8";
        LC_MONETARY = "ru_RU.UTF-8";
        LC_NAME = "ru_RU.UTF-8";
        LC_NUMERIC = "ru_RU.UTF-8";
        LC_PAPER = "ru_RU.UTF-8";
        LC_TELEPHONE = "ru_RU.UTF-8";
        LC_TIME = "en_GB.UTF-8";
      };
    };

    console = {
      packages = with pkgs; [ terminus_font ];
      font = "${pkgs.terminus_font}/share/consolefonts/ter-u24n.psf.gz";
      useXkbConfig = true;

      colors = map hex [
        c.black # 0  black
        c.red # 1  red
        c.green # 2  green
        c.orange # 3  yellow
        c.blue # 4  blue
        c.purple # 5  purple
        c.aqua # 6  aqua
        c.fg4 # 7  light grey (fg)
        c.bg2 # 8  dark grey
        c.brightRed # 9  bright red
        c.brightGreen # 10 bright green
        c.brightYellow # 11 bright yellow
        c.brightBlue # 12 bright blue
        c.brightPurple # 13 bright purple
        c.brightAqua # 14 bright aqua
        c.fg # 15 white / bright fg
      ];
    };

    xdg.portal = {
      enable = true;
      wlr.enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
      config.common.default = [ "gtk" ];
    };

    programs = {
      thunar.enable = true;
      slock = {
        enable = false;
        package = pkgs.slock;
      };
      nix-ld.enable = true;
      steam.enable = true;
      gamemode.enable = true;
      dconf.enable = true;
    };

    services = {
      blueman.enable = true;
      journald.console = "/dev/tty4";
      earlyoom.enable = true;
      thermald.enable = true;

      logind.settings.Login = {
        HandlePowerKey = "ignore";
        HandlePowerKeyLongPress = "poweroff";
      };

      dbus = {
        enable = true;
        implementation = "broker";
      };

      fstrim = {
        enable = true;
        interval = "weekly";
      };
    };

    environment = {
      localBinInPath = true;

      variables = {
        TERM = "xterm-256color";
        TOR_SOCKS_PORT = "9050";
      };

      sessionVariables = {
        XFT_DPI = toString xftDpi;
        XCURSOR_THEME = "Vanilla-DMZ";
        XCURSOR_SIZE = "32";
        _JAVA_AWT_WM_NONREPARENTING = "1";
      }
      // lib.optionalAttrs (dpi == "high") {
        QT_AUTO_SCREEN_SCALE_FACTOR = "1";
        QT_SCALE_FACTOR = "1";
        QT_SCREEN_SCALE_FACTORS = "2;2";
      };

      extraInit = ''
        #Turn off gui for ssh auth
        unset -v SSH_ASKPASS
      '';
    };

    home-manager.users.${user} = {
      xdg.mimeApps = {
        enable = true;
        defaultApplications = {
          "application/pdf" = "zathura.desktop";
          "inode/directory" = [ "thunar.desktop" ];
          "text/html" = "librewolf.desktop";
          "x-scheme-handler/http" = "librewolf.desktop";
          "x-scheme-handler/https" = "librewolf.desktop";
        };
      };

      gtk = {
        enable = true;
        theme.package = pkgs.gruvbox-dark-gtk;
        theme.name = "gruvbox-dark";
        iconTheme = {
          package = pkgs.gruvbox-dark-icons-gtk;
          name = "gruvbox-dark";
        };
      };

      home.pointerCursor = {
        enable = true;
        name = "Vanilla-DMZ";
        package = pkgs.vanilla-dmz;
        size = 32;
      };

      qt = {
        enable = true;
        platformTheme.name = "gtk3";
      };
    };
  };
}
