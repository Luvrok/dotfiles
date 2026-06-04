{ config, lib, pkgs, ... }:

{
  services.picom = {
    enable = true;
    package = pkgs.picom;
  };

  xdg.configFile."picom/picom.conf".text = lib.mkForce ''
    backend = "xrender";
    vsync = true;
    dbus = true;

    dithered-present = true;
    use-damage = true;

    log-level = "warn";
    log-file = "${config.home.homeDirectory}/.cache/picom-log.log";
    show-all-xerrors = true;

    # ============================================================
    # GLOBAL animations (defaults for every window)
    # ============================================================
    animations = (
      # ---- open: subtle grow-in (80% -> 100%) + fade.  NEW windows only ----
      {
        triggers = ["open"];
        opacity = {
          curve = "cubic-bezier(0.25,1,0.25,1)";
          duration = 0.25;
          start = "0";
          end = "window-raw-opacity";
        };
        scale-x = {
          curve = "cubic-bezier(0.25,1,0.25,1)";
          duration = 0.25;
          start = 0.8;
          end = 1;
        };
        scale-y = "scale-x";
        offset-x = "(1 - scale-x) / 2 * window-width";
        offset-y = "(1 - scale-y) / 2 * window-height";
        shadow-scale-x = "scale-x";
        shadow-scale-y = "scale-y";
        shadow-offset-x = "offset-x";
        shadow-offset-y = "offset-y";
      },

      # ---- close: subtle shrink (100% -> 80%) + fade.  DESTROYED windows only ----
      {
        triggers = ["close"];
        opacity = {
          curve = "cubic-bezier(0.25,1,0.25,1)";
          duration = 0.25;
          start = "window-raw-opacity-before";
          end = 0;
        };
        scale-x = {
          curve = "cubic-bezier(0.25,1,0.25,1)";
          duration = 0.25;
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
      },

      # ---- show / hide: fade only (no scale, no slide) ----
      {
        triggers = ["show"];
        opacity = {
          curve = "cubic-bezier(0.25,1,0.25,1)";
          duration = 0.375;
          start = "0";
          end = "window-raw-opacity";
        };
      },
      {
        triggers = ["hide"];
        opacity = {
          curve = "cubic-bezier(0.25,1,0.25,1)";
          duration = 0.375;
          start = "window-raw-opacity-before";
          end = 0;
        };
      },

      # ---- size / position: smooth move & resize (mouse drag, retiling) ----
      {
        triggers = ["size", "position"];
        scale-x = {
          curve = "cubic-bezier(0.25,0.8,0.25,1)";
          duration = 0.375;
          start = "window-width-before / window-width";
          end = 1;
        };
        scale-y = {
          curve = "cubic-bezier(0.25,0.8,0.25,1)";
          duration = 0.375;
          start = "window-height-before / window-height";
          end = 1;
        };
        offset-x = {
          curve = "cubic-bezier(0.25,0.8,0.25,1)";
          duration = 0.375;
          start = "window-x-before - window-x";
          end = 0;
        };
        offset-y = {
          curve = "cubic-bezier(0.25,0.8,0.25,1)";
          duration = 0.375;
          start = "window-y-before - window-y";
          end = 0;
        };
        shadow-scale-x = "scale-x";
        shadow-scale-y = "scale-y";
        shadow-offset-x = "offset-x";
        shadow-offset-y = "offset-y";
      }
    );

    # --- PER-WINDOW rules (override the global animations) ---
    rules = (
      # - dunst + utility windows. No open/show/close/hide animation: appear/disappear instantly. -
      {
        match = "class_g = 'Dunst' || window_type = 'utility'";
        animations = (
          {
            triggers = ["open", "show"];
            opacity = { duration = 0.01; start = "window-raw-opacity"; end = "window-raw-opacity"; };
          },
          {
            triggers = ["close", "hide"];
            opacity = { duration = 0.01; start = 0; end = 0; };
          }
        );
      },

      # - rofi. Pure opacity fade, no scale/slide.
      {
        match = "class_g = 'Rofi'";
        animations = (
          {
            triggers = ["open", "show"];
            opacity = {
              curve = "cubic-bezier(0.25,1,0.25,1)";
              duration = 0.4;
              start = "0";
              end = "window-raw-opacity";
            };
          },
          {
            triggers = ["close", "hide"];
            opacity = {
              curve = "cubic-bezier(0.25,1,0.25,1)";
              duration = 0.4;
              start = "window-raw-opacity-before";
              end = 0;
            };
          }
        );
      },

      # - awesomebar-hidden windows (_DWM_HIDDEN set by dwm hide()/show()) -
      {
        match = "_DWM_HIDDEN@ = 1";
        animations = (
          {
            triggers = ["open", "show"];
            opacity = {
              curve = "cubic-bezier(0.25,1,0.25,1)";
              duration = 0.375;
              start = "0";
              end = "window-raw-opacity";
            };
            offset-y = {
              curve = "cubic-bezier(0.25,1,0.25,1)";
              duration = 0.375;
              start = "window-monitor-y + window-monitor-height - window-y";
              end = 0;
            };
            shadow-offset-y = "offset-y";
          },
          {
            triggers = ["close", "hide"];
            opacity = {
              curve = "cubic-bezier(0.25,1,0.25,1)";
              duration = 0.375;
              start = "window-raw-opacity-before";
              end = 0;
            };
            offset-y = {
              curve = "cubic-bezier(0.25,1,0.25,1)";
              duration = 0.375;
              start = 0;
              end = "window-monitor-y + window-monitor-height - window-y";
            };
            shadow-offset-y = "offset-y";
          }
        );
      },

      # - scratchpad (WM_CLASS "spterm"). Slide in/out from the TOP -
      {
        match = "_DWM_SCRATCHPAD@ = 1";
        animations = (
          # Case B: hidden by UNMAPPING it (map/unmap, e.g. with windowmap).
          {
            triggers = ["open", "show"];
            opacity = {
              curve = "cubic-bezier(0.4,0,0.2,1)";
              duration = 0.375;
              start = "0";
              end = "window-raw-opacity";
            };
            offset-y = {
              curve = "cubic-bezier(0.4,0,0.2,1)";
              duration = 0.375;
              start = "0 - window-height - window-y";
              end = 0;
            };
            shadow-offset-y = "offset-y";
          },
          {
            triggers = ["close", "hide"];
            opacity = {
              curve = "cubic-bezier(0.4,0,0.2,1)";
              duration = 0.375;
              start = "window-raw-opacity-before";
              end = 0;
            };
            offset-y = {
              curve = "cubic-bezier(0.4,0,0.2,1)";
              duration = 0.375;
              start = 0;
              end = "0 - window-height - window-y";
            };
            shadow-offset-y = "offset-y";
          },
          {
            triggers = ["size", "position"];
            scale-x = {
              curve = "cubic-bezier(0.25,0.8,0.25,1)";
              duration = 0.375;
              start = "window-width-before / window-width";
              end = 1;
            };
            scale-y = {
              curve = "cubic-bezier(0.25,0.8,0.25,1)";
              duration = 0.375;
              start = "window-height-before / window-height";
              end = 1;
            };
            offset-x = {
              curve = "cubic-bezier(0.25,0.8,0.25,1)";
              duration = 0.375;
              start = "window-x-before - window-x";
              end = 0;
            };
            offset-y = {
              curve = "cubic-bezier(0.25,0.8,0.25,1)";
              duration = 0.375;
              start = "window-y-before - window-y";
              end = 0;
            };
            shadow-scale-x = "scale-x";
            shadow-scale-y = "scale-y";
            shadow-offset-x = "offset-x";
            shadow-offset-y = "offset-y";
          }
        );
      },

      # - scratchpad dock (WM_CLASS "spdock"). Slide in/out from the RIGHT (open/show, close/hide) -
      {
        match = "class_g = 'spdock'";
        animations = (
          {
            triggers = ["open", "show"];
            opacity = {
              curve = "cubic-bezier(0.25,1,0.25,1)";
              duration = 0.375;
              start = "0";
              end = "window-raw-opacity";
            };
            offset-x = {                    # ← изменили на offset-x
              curve = "cubic-bezier(0.25,1,0.25,1)";
              duration = 0.375;
              start = "window-monitor-x + window-monitor-width - window-x";  # справа
              end = 0;
            };
            shadow-offset-x = "offset-x";   # ← тоже по X
          },
          {
            triggers = ["close", "hide"];
            opacity = {
              curve = "cubic-bezier(0.25,1,0.25,1)";
              duration = 0.375;
              start = "window-raw-opacity-before";
              end = 0;
            };
            offset-x = {                    # ← изменили на offset-x
              curve = "cubic-bezier(0.25,1,0.25,1)";
              duration = 0.375;
              start = 0;
              end = "window-monitor-x + window-monitor-width - window-x";   # уезжает вправо
            };
            shadow-offset-x = "offset-x";   # ← тоже по X
          },
          {
            triggers = ["size", "position"];
            scale-x = {
              curve = "cubic-bezier(0.25,0.8,0.25,1)";
              duration = 0.375;
              start = "window-width-before / window-width";
              end = 1;
            };
            scale-y = {
              curve = "cubic-bezier(0.25,0.8,0.25,1)";
              duration = 0.375;
              start = "window-height-before / window-height";
              end = 1;
            };
            offset-x = {
              curve = "cubic-bezier(0.25,0.8,0.25,1)";
              duration = 0.375;
              start = "window-x-before - window-x";
              end = 0;
            };
            offset-y = {
              curve = "cubic-bezier(0.25,0.8,0.25,1)";
              duration = 0.375;
              start = "window-y-before - window-y";
              end = 0;
            };
            shadow-scale-x = "scale-x";
            shadow-scale-y = "scale-y";
            shadow-offset-x = "offset-x";
            shadow-offset-y = "offset-y";
          }
        );
      },
    );
  '';
}
