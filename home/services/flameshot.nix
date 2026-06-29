{ config, pkgs, ... }:

{
  services.flameshot = {
    enable = true;
    settings = {
      General = {
        savePath = "${config.home.homeDirectory}/HOME/wizzard/media/screenshot";
        saveAsFileExtension = ".png";
        showHelp = false;
        showSidePanelButton = false;
        showDesktopNotification = false;
        filenamePattern = "%F_%H-%M";
        disabledTrayIcon = true;
        drawThickness = 1;
        startupLaunch = false;
        copyPathAfterSave = true;
        saveAfterCopy = false;
        userColors = "#fbf1c7, #ebdbb2, #d5c4a1, #bdae93, #a89984, #928374, #d65d0e, #cc241d, #98971a, #458588, #b16286, #689d6a, #d79921, #fbf1c7";
        uiColor = "#d65d0e";
        contrastUiColor = "#fbf1c7";
        drawColor = "#d65d0e";
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
    Install.WantedBy = pkgs.lib.mkForce [ "graphical-session.target" ];
  };
}
