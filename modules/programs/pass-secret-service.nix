{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.galaxy.programs.pass-secret-service.enable =
    lib.mkEnableOption "pass-secret-service (Secret Service API on top of pass)";

  config = lib.mkIf config.galaxy.programs.pass-secret-service.enable {
    home-manager.users.${config.galaxy.host.user} = {
      home.packages = with pkgs; [
        pass-secret-service
        libsecret
      ];

      services = {
        pass-secret-service.enable = true;
      };

      systemd.user.services.pass-secret-service = {
        Service = {
          Type = "dbus";
          Environment = [
            "GPG_TTY=/dev/tty1"
            "DISPLAY=:0"
          ];
          BusName = "org.freedesktop.secrets";
        };
        Unit = rec {
          Wants = [ "gpg-agent.service" ];
          After = Wants;
          PartOf = [ "graphical-session-pre.target" ];
        };
      };
    };
  };
}
