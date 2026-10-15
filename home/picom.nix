# picom (pijulius fork) for i3
{
  lib,
  pkgs,
  inputs,
  ...
}:
let
  # 1 normal, 8 slow motion with debug logs
  slow = 8;
  d = x: toString (x * slow);
in
{
  services.picom = {
    enable = true;
    package = pkgs.picom.overrideAttrs (old: {
      src = inputs.picom-pijulius;
      # no carousel on big jumps: lower index -> inverse, higher -> normal
      postPatch = (old.postPatch or "") + ''
        substituteInPlace src/wm/win.c \
          --replace-fail 'ps->root_desktop_switch_direction >= -1' '1' \
          --replace-fail 'ps->root_desktop_switch_direction > 1' '0'
      '';
    });
  };

  # i3-sp reads its fade time from here
  xdg.configFile."picom/fade".text = d 0.15;

  # i3-ws-anim keeps its _WS_SWITCH tags this long, slow mode included
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

    animations = (

      # workspace switch by ewmh index, i3-ws-anim rules below override it
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
        crop-x = "window-monitor-x";
        crop-y = "window-monitor-y";
        crop-width = "window-monitor-width";
        crop-height = "window-monitor-height";
      },

      # slide down from above. reset: never start from below after a quick re-show
      {
        triggers = [ "open", "show" ];
        offset-y = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = "0 - window-monitor-height * 0.06"; end = 0; reset = true; };
        shadow-offset-y = "offset-y";
        opacity = { curve = "cubic-bezier(0.4, 0, 0.2, 1)"; duration = ${d 0.25}; start = 0; end = "window-raw-opacity"; };
        shadow-opacity = "opacity";
        blur-opacity = "opacity";
      },

      # sink down. close of i3 windows is instant, see rules
      {
        triggers = [ "close", "hide" ];
        offset-y = { curve = "cubic-bezier(0.33, 1, 0.68, 1)"; duration = ${d 0.25}; start = 0; end = "window-monitor-height * 0.06"; };
        shadow-offset-y = "offset-y";
        opacity = { curve = "linear"; duration = ${d 0.15}; start = "window-raw-opacity-before"; end = 0; };
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

    rules = (

      # bar and desktop: no animations
      {
        match = "window_type = 'dock' || window_type = 'desktop'";
        animations = (
          { triggers = [ "open", "show", "close", "hide" ]; offset-x = 0; }
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

      # i3 windows lose their content before picom sees the close, so no anim.
      # i3-sp kill fades them first
      {
        match = "!override_redirect";
        animations = (
          { triggers = [ "close" ]; offset-x = 0; }
        );
      },

      # floating: no size/position anim, dragging stays snappy
      {
        match = "I3_FLOATING_WINDOW@";
        animations = (
          { triggers = [ "size", "position" ]; offset-x = 0; }
        );
      },

      # i3-ws-anim tags both workspaces before a switch: 1 going up, 2 going down.
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
            crop-x = "window-monitor-x";
            crop-y = "window-monitor-y";
            crop-width = "window-monitor-width";
            crop-height = "window-monitor-height";
          }
        );
      },
      # flameshot: no animations, the overlay appears and vanishes instantly
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
