# picom (pijulius fork) for i3
{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # 1 normal, 8 slow motion with debug logs
  slow = 1;
  d = x: toString (x * slow);
in
{
  services.picom = {
    enable = true;
    package = pkgs.picom.overrideAttrs (old: {
      src = inputs.picom-pijulius;
      # win.c: no carousel on big jumps, lower index -> inverse, higher -> normal.
      # layout.c: a borderless window (tabbed tags) shown again mid-anim was
      # skipped until the app drew, it blinked out. now it shows its old image
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/wm/win.c \
          --replace-fail 'ps->root_desktop_switch_direction >= -1' '1' \
          --replace-fail 'ps->root_desktop_switch_direction > 1' '0'
        substituteInPlace src/renderer/layout.c \
          --replace-fail 'if (!w->ever_damaged || !w_opts.paint) {' \
                         'if ((!w->ever_damaged && !w->saved_win_image) || !w_opts.paint) {' \
          --replace-fail '(float)win_animatable_get(w, WIN_SCRIPT_SAVED_IMAGE_BLEND);' \
                         'w->ever_damaged ? (float)win_animatable_get(w, WIN_SCRIPT_SAVED_IMAGE_BLEND) : 1;'
      '';
    });
  };

  # read by i3-sp and i3-ws-anim, slow mode included
  xdg.configFile."picom/fade".text = d 0.15;
  xdg.configFile."picom/ws-untag".text = d 0.3;

  # mkForce: the hm module writes this file too and adds keys that clash with rules
  xdg.configFile."picom/picom.conf".text = lib.mkForce ''
    backend = "glx";
    vsync = true;
    use-damage = true;
    # unredirected screen = no animations under fullscreen windows
    unredir-if-possible = false;
    log-level = "${if slow > 1 then "debug" else "warn"}";
    # i3-sp sets opacity on the app window
    detect-client-opacity = true;

    shadow = false;
    corner-radius = 0;

    # saved-image-blend on fade-ins: a window shown again mid-anim starts from
    # its old image and fades into the new one, the app may not have drawn
    # yet (i3 paints the frame, the inside is black). fresh windows have none
    animations = (

      # workspace switch by ewmh index, i3-ws-anim tags override it
      {
        triggers = [ "workspace-out" ];
        offset-x = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = 0; end = "0 - window-monitor-width * 0.06"; };
        shadow-offset-x = "offset-x";
        opacity = { curve = "linear"; duration = ${d 0.15}; start = "window-raw-opacity-before"; end = 0; };
        shadow-opacity = "opacity";
        blur-opacity = "opacity";
        crop-x = "window-monitor-x";
        crop-y = "window-monitor-y";
        crop-width = "window-monitor-width";
        crop-height = "window-monitor-height";
      },
      {
        triggers = [ "workspace-out-inverse" ];
        offset-x = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = 0; end = "window-monitor-width * 0.06"; };
        shadow-offset-x = "offset-x";
        opacity = { curve = "linear"; duration = ${d 0.15}; start = "window-raw-opacity-before"; end = 0; };
        shadow-opacity = "opacity";
        blur-opacity = "opacity";
        crop-x = "window-monitor-x";
        crop-y = "window-monitor-y";
        crop-width = "window-monitor-width";
        crop-height = "window-monitor-height";
      },
      {
        triggers = [ "workspace-in" ];
        offset-x = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = "window-monitor-width * 0.06"; end = 0; };
        shadow-offset-x = "offset-x";
        opacity = { curve = "cubic-bezier(0.4, 0, 0.2, 1)"; duration = ${d 0.25}; start = 0; end = "window-raw-opacity"; };
        shadow-opacity = "opacity";
        blur-opacity = "opacity";
        saved-image-blend = { curve = "cubic-bezier(0.32, 0, 0.67, 0)"; duration = ${d 0.25}; start = 1; end = 0; };
        crop-x = "window-monitor-x";
        crop-y = "window-monitor-y";
        crop-width = "window-monitor-width";
        crop-height = "window-monitor-height";
      },
      {
        triggers = [ "workspace-in-inverse" ];
        offset-x = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = "0 - window-monitor-width * 0.06"; end = 0; };
        shadow-offset-x = "offset-x";
        opacity = { curve = "cubic-bezier(0.4, 0, 0.2, 1)"; duration = ${d 0.25}; start = 0; end = "window-raw-opacity"; };
        shadow-opacity = "opacity";
        blur-opacity = "opacity";
        saved-image-blend = { curve = "cubic-bezier(0.32, 0, 0.67, 0)"; duration = ${d 0.25}; start = 1; end = 0; };
        crop-x = "window-monitor-x";
        crop-y = "window-monitor-y";
        crop-width = "window-monitor-width";
        crop-height = "window-monitor-height";
      },

      # new window slides down from above. reset: never start from below after a quick re-show
      {
        triggers = [ "open" ];
        offset-y = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = "0 - window-monitor-height * 0.06"; end = 0; reset = true; };
        shadow-offset-y = "offset-y";
        opacity = { curve = "cubic-bezier(0.4, 0, 0.2, 1)"; duration = ${d 0.25}; start = 0; end = "window-raw-opacity"; };
        shadow-opacity = "opacity";
        blur-opacity = "opacity";
      },

      # sink down. close of i3 windows is instant, see rules
      {
        triggers = [ "close" ];
        offset-y = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = 0; end = "window-monitor-height * 0.06"; };
        shadow-offset-y = "offset-y";
        opacity = { curve = "linear"; duration = ${d 0.15}; start = "window-raw-opacity-before"; end = 0; };
        shadow-opacity = "opacity";
        blur-opacity = "opacity";
      },

      # plain show/hide is i3 doing it on its own, like hiding everything under
      # a fullscreen window. just a quick fade, nothing moves
      {
        triggers = [ "show" ];
        opacity = { curve = "cubic-bezier(0.4, 0, 0.2, 1)"; duration = ${d 0.1}; start = 0; end = "window-raw-opacity"; };
        shadow-opacity = "opacity";
        blur-opacity = "opacity";
        saved-image-blend = { curve = "cubic-bezier(0.32, 0, 0.67, 0)"; duration = ${d 0.1}; start = 1; end = 0; };
      },
      {
        triggers = [ "hide" ];
        opacity = { curve = "linear"; duration = ${d 0.1}; start = "window-raw-opacity-before"; end = 0; };
        shadow-opacity = "opacity";
        blur-opacity = "opacity";
      },

      # i3-sp fade, same sink while the window is still on top
      {
        triggers = [ "decrease-opacity" ];
        offset-y = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = 0; end = "window-monitor-height * 0.06"; };
        shadow-offset-y = "offset-y";
        opacity = { curve = "linear"; duration = ${d 0.15}; start = "window-raw-opacity-before"; end = "window-raw-opacity"; };
        shadow-opacity = "opacity";
        blur-opacity = "opacity";
      },

      # tiles glide to their new place. "geometry" never fires in this fork
      {
        triggers = [ "size", "position" ];
        scale-x = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = "window-width-before / window-width"; end = 1; };
        scale-y = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = "window-height-before / window-height"; end = 1; };
        offset-x = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = "window-x-before - window-x"; end = 0; };
        offset-y = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = "window-y-before - window-y"; end = 0; };
        saved-image-blend = { duration = ${d 0.25}; start = 1; end = 0; };
        shadow-scale-x = "scale-x";
        shadow-scale-y = "scale-y";
        shadow-offset-x = "offset-x";
        shadow-offset-y = "offset-y";
      }
    );

    # later rules win
    rules = (

      # bar: fades when i3 hides it for a fullscreen window, no drift.
      # nothing on open/close, eww restarts on every i3 reload
      {
        match = "window_type = 'dock' || window_type = 'desktop'";
        animations = (
          { triggers = [ "open", "close" ]; offset-x = 0; },
          {
            triggers = [ "show", "workspace-in", "workspace-in-inverse" ];
            opacity = { curve = "cubic-bezier(0.4, 0, 0.2, 1)"; duration = ${d 0.25}; start = 0; end = "window-raw-opacity"; };
            shadow-opacity = "opacity";
            blur-opacity = "opacity";
            saved-image-blend = { curve = "cubic-bezier(0.32, 0, 0.67, 0)"; duration = ${d 0.25}; start = 1; end = 0; };
          },
          {
            triggers = [ "hide", "workspace-out", "workspace-out-inverse" ];
            opacity = { curve = "linear"; duration = ${d 0.15}; start = "window-raw-opacity-before"; end = 0; };
            shadow-opacity = "opacity";
            blur-opacity = "opacity";
          }
        );
      },

      # menus and tooltips: short fade
      {
        match = "window_type = 'menu' || window_type = 'dropdown_menu' || window_type = 'popup_menu' || window_type = 'tooltip' || window_type = 'combo'";
        animations = (
          {
            triggers = [ "open", "show" ];
            opacity = { duration = ${d 0.08}; start = 0; end = "window-raw-opacity"; };
          },
          {
            triggers = [ "close", "hide" ];
            opacity = { duration = ${d 0.06}; start = "window-raw-opacity-before"; end = 0; };
          }
        );
      },

      # an i3 window loses its content before picom sees the close, so no anim.
      # i3-sp kill fades it first
      {
        match = "!override_redirect";
        animations = (
          { triggers = [ "close" ]; offset-x = 0; }
        );
      },

      # floating: dragging stays snappy
      {
        match = "I3_FLOATING_WINDOW@";
        animations = (
          { triggers = [ "size", "position" ]; offset-x = 0; }
        );
      },

      # fullscreen window takes the screen at once
      {
        match = "_NET_WM_STATE@[*] = '_NET_WM_STATE_FULLSCREEN'";
        animations = (
          { triggers = [ "open", "show", "size", "position" ]; offset-x = 0; }
        );
      },

      # i3-sp tags a scratchpad before bringing it, it slides down like a new window
      {
        match = "_SP_SHOW@";
        animations = (
          {
            triggers = [ "show" ];
            offset-y = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = "0 - window-monitor-height * 0.06"; end = 0; reset = true; };
            shadow-offset-y = "offset-y";
            opacity = { curve = "cubic-bezier(0.4, 0, 0.2, 1)"; duration = ${d 0.25}; start = 0; end = "window-raw-opacity"; };
            shadow-opacity = "opacity";
            blur-opacity = "opacity";
            saved-image-blend = { curve = "cubic-bezier(0.32, 0, 0.67, 0)"; duration = ${d 0.25}; start = 1; end = 0; };
          }
        );
      },

      # i3-ws-anim tags both tags of a switch: 1 going up, 2 going down.
      # covers empty tags too, where the fork only sends hide/show
      {
        match = "_WS_SWITCH@ = 1";
        animations = (
          {
            triggers = [ "hide", "workspace-out", "workspace-out-inverse" ];
            offset-x = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = 0; end = "0 - window-monitor-width * 0.06"; };
            shadow-offset-x = "offset-x";
            opacity = { curve = "linear"; duration = ${d 0.15}; start = "window-raw-opacity-before"; end = 0; };
            shadow-opacity = "opacity";
            blur-opacity = "opacity";
            crop-x = "window-monitor-x";
            crop-y = "window-monitor-y";
            crop-width = "window-monitor-width";
            crop-height = "window-monitor-height";
          },
          {
            triggers = [ "open", "show", "workspace-in", "workspace-in-inverse" ];
            offset-x = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = "window-monitor-width * 0.06"; end = 0; };
            shadow-offset-x = "offset-x";
            opacity = { curve = "cubic-bezier(0.4, 0, 0.2, 1)"; duration = ${d 0.25}; start = 0; end = "window-raw-opacity"; };
            shadow-opacity = "opacity";
            blur-opacity = "opacity";
            saved-image-blend = { curve = "cubic-bezier(0.32, 0, 0.67, 0)"; duration = ${d 0.25}; start = 1; end = 0; };
            crop-x = "window-monitor-x";
            crop-y = "window-monitor-y";
            crop-width = "window-monitor-width";
            crop-height = "window-monitor-height";
          }
        );
      },
      {
        match = "_WS_SWITCH@ = 2";
        animations = (
          {
            triggers = [ "hide", "workspace-out", "workspace-out-inverse" ];
            offset-x = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = 0; end = "window-monitor-width * 0.06"; };
            shadow-offset-x = "offset-x";
            opacity = { curve = "linear"; duration = ${d 0.15}; start = "window-raw-opacity-before"; end = 0; };
            shadow-opacity = "opacity";
            blur-opacity = "opacity";
            crop-x = "window-monitor-x";
            crop-y = "window-monitor-y";
            crop-width = "window-monitor-width";
            crop-height = "window-monitor-height";
          },
          {
            triggers = [ "open", "show", "workspace-in", "workspace-in-inverse" ];
            offset-x = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = "0 - window-monitor-width * 0.06"; end = 0; };
            shadow-offset-x = "offset-x";
            opacity = { curve = "cubic-bezier(0.4, 0, 0.2, 1)"; duration = ${d 0.25}; start = 0; end = "window-raw-opacity"; };
            shadow-opacity = "opacity";
            blur-opacity = "opacity";
            saved-image-blend = { curve = "cubic-bezier(0.32, 0, 0.67, 0)"; duration = ${d 0.25}; start = 1; end = 0; };
            crop-x = "window-monitor-x";
            crop-y = "window-monitor-y";
            crop-width = "window-monitor-width";
            crop-height = "window-monitor-height";
          }
        );
      },

      # i3-sp tags what's under a closing fullscreen window: it's there at once,
      # the closing window fades on top of it
      {
        match = "_SP_NOW@";
        animations = (
          { triggers = [ "show" ]; offset-x = 0; }
        );
      },

      # flameshot: no animations, its overlay appears and vanishes at once
      {
        match = "class_g = 'flameshot'";
        animations = (
          {
            triggers = [ "open", "show", "close", "hide", "size", "position",
                         "increase-opacity", "decrease-opacity",
                         "workspace-in", "workspace-in-inverse",
                         "workspace-out", "workspace-out-inverse" ];
            offset-x = 0;
          }
        );
      }
    );
  '';
}
