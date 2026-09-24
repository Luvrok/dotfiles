{
  config,
  lib,
  pkgs,
  ...
}:

let
  c = config.galaxy.theme.colors;
in
{
  options.galaxy.desktop.flameshot.enable = lib.mkEnableOption "flameshot";

  config = lib.mkIf config.galaxy.desktop.flameshot.enable {
    home-manager.users.${config.galaxy.host.user} =
      { config, ... }:
      {
        services.flameshot = {
          enable = true;
          settings = {
            General = {
              savePath = "${config.home.homeDirectory}/HOME/wizzard/media/screenshot";
              saveAsFileExtension = ".png";
              useX11LegacyScreenshot = true;
              captureActiveMonitor = true;
              showHelp = false;
              showSidePanelButton = false;
              showDesktopNotification = false;
              filenamePattern = "%F_%H-%M";
              disabledTrayIcon = true;
              drawThickness = 1;
              startupLaunch = false;
              copyPathAfterSave = true;
              saveAfterCopy = false;
              userColors = lib.concatStringsSep ", " [
                c.fg0
                c.fg
                c.fg2
                c.fg3
                c.fg4
                c.gray
                c.orange
                c.red
                c.green
                c.blue
                c.purple
                c.aqua
                c.yellow
                c.fg0
              ];
              uiColor = c.orange;
              contrastUiColor = c.fg0;
              drawColor = c.orange;
            };
            Shortcuts = {
              TYPE_COPY = "Ctrl+c";
            };
          };
        };

        systemd.user.services.flameshot = {
          Unit = {
            After = [ "graphical-session.target" ];
            PartOf = [ "graphical-session.target" ];
          };
          Service = {
            ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
          };
          Install.WantedBy = lib.mkForce [ "graphical-session.target" ];
        };
      };
  };
}
