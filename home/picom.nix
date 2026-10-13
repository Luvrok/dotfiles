{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  bounce = "cubic-bezier(0.25, 1.35, 0.5, 1)";
  bounceStrong = "cubic-bezier(0.34, 1.56, 0.64, 1)";
  easeIn = "cubic-bezier(0.55, 0, 1, 0.45)";
  anticipate = "cubic-bezier(0.36, 0, 0.66, -0.56)";

  wsInDuration = "0.38";
  wsOutDuration = "0.25";
  openDuration = "0.3";
  geometryDuration = "0.35";
  closeDuration = "0.22";

  crop = ''
    crop-x = "window-monitor-x";
    crop-y = "window-monitor-y";
    crop-width = "window-monitor-width";
    crop-height = "window-monitor-height";
  '';

  slide = trigger: curve: duration: from: to: opacity: ''
    {
      triggers = [ "${trigger}" ];
      offset-x = {
        curve = "${curve}";
        duration = ${duration};
        start = "${from}";
        end = "${to}";
      };
      shadow-offset-x = "offset-x";
      opacity = {
        duration = ${duration};
        start = "${opacity}";
        end = "${opacity}";
      };
      blur-opacity = "opacity";
      shadow-opacity = "opacity";
      ${crop}
    }
  '';
in
{
  services.picom = {
    enable = true;

    package = pkgs.picom.overrideAttrs (_: {
      src = inputs.picom-pijulius;
    });
  };

  xdg.configFile."picom/picom.conf".text = lib.mkForce ''
    backend = "glx";
    vsync = true;
    dbus = false;
    use-damage = true;

    unredir-if-possible = true;

    log-level = "warn";
    log-file = "${config.home.homeDirectory}/.cache/picom-log.log";
    show-all-xerrors = true;

    animations = (
      ${slide "workspace-out" easeIn wsOutDuration "0" "0 - window-monitor-width" "window-raw-opacity-before"},
      ${slide "workspace-out-inverse" easeIn wsOutDuration "0" "window-monitor-width" "window-raw-opacity-before"},
      ${slide "workspace-in" bounce wsInDuration "window-monitor-width" "0" "window-raw-opacity"},
      ${slide "workspace-in-inverse" bounce wsInDuration "0 - window-monitor-width" "0" "window-raw-opacity"},
      {
        triggers = [ "open", "show" ];
        scale-x = {
          curve = "${bounceStrong}";
          duration = ${openDuration};
          start = 0.85;
          end = 1;
        };
        scale-y = "scale-x";
        offset-x = "(1 - scale-x) / 2 * window-width";
        offset-y = "(1 - scale-y) / 2 * window-height";
        shadow-scale-x = "scale-x";
        shadow-scale-y = "scale-y";
        shadow-offset-x = "offset-x";
        shadow-offset-y = "offset-y";
        opacity = {
          duration = 0.12;
          start = 0;
          end = "window-raw-opacity";
        };
        blur-opacity = "opacity";
        shadow-opacity = "opacity";
      },
      {
        triggers = [ "close", "hide" ];
        scale-x = {
          curve = "${anticipate}";
          duration = ${closeDuration};
          start = 1;
          end = 0.8;
        };
        scale-y = "scale-x";
        offset-x = "(1 - scale-x) / 2 * window-width";
        offset-y = "(1 - scale-y) / 2 * window-height";
        shadow-scale-x = "scale-x";
        shadow-scale-y = "scale-y";
        shadow-offset-x = "offset-x";
        shadow-offset-y = "offset-y";
        opacity = {
          curve = "${easeIn}";
          duration = ${closeDuration};
          start = "window-raw-opacity-before";
          end = 0;
        };
        blur-opacity = "opacity";
        shadow-opacity = "opacity";
      },
      {
        triggers = [ "size", "position" ];
        scale-x = {
          curve = "${bounce}";
          duration = ${geometryDuration};
          start = "window-width-before / window-width";
          end = 1;
        };
        scale-y = {
          curve = "${bounce}";
          duration = ${geometryDuration};
          start = "window-height-before / window-height";
          end = 1;
        };
        offset-x = {
          curve = "${bounce}";
          duration = ${geometryDuration};
          start = "window-x-before - window-x";
          end = 0;
        };
        offset-y = {
          curve = "${bounce}";
          duration = ${geometryDuration};
          start = "window-y-before - window-y";
          end = 0;
        };
        saved-image-blend = {
          duration = ${geometryDuration};
          start = 1;
          end = 0;
        };
        shadow-scale-x = "scale-x";
        shadow-scale-y = "scale-y";
        shadow-offset-x = "offset-x";
        shadow-offset-y = "offset-y";
      }
    );

    rules = (
      {
        match = "class_g = 'mpv' || class_g = 'librewolf'";
        unredir = false;
      },
      {
        match = "I3_FLOATING_WINDOW@";
        animations = (
          {
            triggers = [ "size", "position" ];
            offset-x = 0;
          }
        );
      }
    );
  '';
}
