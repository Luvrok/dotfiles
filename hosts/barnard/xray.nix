{ lib, username, ... }:

let
  hasConfig = builtins.pathExists ./xray.json;
in
{
  warnings = lib.optional (
    !hasConfig
  ) "hosts/barnard/xray.json is missing (or not git added), xray is off";

  services.xray = lib.mkIf hasConfig {
    enable = true;
    settingsFile = ./xray.json;
  };

  systemd.services.xray = lib.mkIf hasConfig {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    startLimitIntervalSec = 0;
    serviceConfig = {
      Restart = "always";
      RestartSec = 10;
    };
  };

  security.polkit.extraConfig = lib.mkIf hasConfig ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "xray.service" &&
          subject.user == "${username}") {
        var verb = action.lookup("verb");
        if (verb == "start" || verb == "stop" || verb == "restart")
          return polkit.Result.YES;
      }
    });
  '';
}
