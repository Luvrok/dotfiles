{ config, pkgs, ... }: 

{
  systemd.user.targets.tray = {
    Unit = {
      Description = "Home Manager System Tray";
      Requires = [ "graphical-session-pre.target" ];
    };
  };

  systemd.user.services.flameshot = {
    Unit = {
      Description = "Flameshot screenshot tool";
      Requires = [ "tray.target" ];
      After = [ "display-manager.service" "default.target" "graphical-session.target" "tray.target" ];
    };

    Install = { WantedBy = [ "default.target" "graphical-session.target" ]; };

    Service = {
      ExecStart = "${pkgs.flameshot}/bin/flameshot";
      Environment = [
        "DISPLAY=:0"
        "XAUTHORITY=${config.home.homeDirectory}/.Xauthority"
      ];
      Restart = "on-abort";
    };
  };

  services.flameshot = {
    enable = true;

    # NOTE: https://github.com/flameshot-org/flameshot/blob/master/flameshot.example.ini
    settings = {
      General = {
        # Image Save Path
        savePath= "${config.home.homeDirectory}/HOME/wizzard/media/screenshot";

        # Default file extension for screenshots
        saveAsFileExtension = ".png";

        # Show the help screen on startup (bool)
        showHelp = false;

        # Show the side panel button (bool)
        showSidePanelButton = false;

        # Show desktop notifications (bool)
        showDesktopNotification = false;

        # Filename pattern using C++ strftime formatting
        filenamePattern = "%F_%H-%M";

        # Whether the tray icon is disabled (bool)
        disabledTrayIcon = true;

        #  Last used tool thickness
        drawThickness = 1;

        # Launch at startup (bool)
        startupLaunch = false;

        # Copy path to image after save (bool)
        copyPathAfterSave = true;

        # Save image after copy (bool)
        saveAfterCopy = false;

        #
        # [[ Theme ]]
        #
        # List of colors for color picker
        # The colors are arranged counter-clockwise with the first being set to the right of the cursor
        # Colors are any valid hex code or W3C color name
        # "picker" adds a custom color picke
        userColors = "#fbf1c7, #ebdbb2, #d5c4a1, #bdae93, #a89984, #928374, #d65d0e, #cc241d, #98971a, #458588, #b16286, #689d6a, #d79921, #fbf1c7";

        # Main UI color
        uiColor = "#d65d0e";

        # Contrast UI color
        contrastUiColor= "#fbf1c7";

        # Last used color
        drawColor = "#d65d0e";
      };

      Shortcuts = {
        TYPE_COPY = "Ctrl+c";
      };
    };
  };
}
