{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.galaxy.desktop.picom.enable = lib.mkEnableOption "picom";

  config = lib.mkIf config.galaxy.desktop.picom.enable {
    home-manager.users.${config.galaxy.host.user} =
      { config, ... }:
      {
        services.picom = {
          enable = true;
          package = pkgs.picom;
          backend = "glx";
          vSync = true;

          # opacityRules = [
          #   "100:class_g = 'kitty' && focused"
          #   "95:class_g = 'kitty' && !focused"
          # ];

          fade = true;
          fadeSteps = [
            0.03
            0.03
          ];
          fadeDelta = 6;
          fadeExclude = [ "_NET_WM_STATE *= '_NET_WM_STATE_FULLSCREEN'" ];

          settings.log-file = "${config.home.homeDirectory}/.cache/picom-log.log";
          extraConfig = builtins.readFile ./picom.conf;
        };
      };
  };
}
