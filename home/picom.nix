{ config, pkgs, ... }:

{
  services.picom = {
    enable = true;
    backend = "glx";
    vSync = true;

    package = pkgs.picom;

    opacityRules = [
      "100:class_g = 'kitty' && focused"
      "90:class_g = 'kitty' && !focused"
    ];

    settings = {
      dbus = false;

      fading = true;
      fade-in-step = 0.03;
      fade-out-step = 0.03;
      fade-delta = 6;
      no-fading-openclose = true;

      blur = {
        method = "dual_kawase";
        strength = 3;
        size = 10;
      };

      blur-background = true;
      blur-background-frame = false;
      blur-background-fixed = false;

      use-damage = true;

      # Exclude dwm statusbar from focus detection so it doesn't affect focused/unfocused rules, (prevents bar/dmenu from interfering with opacity/fade logic)
      # https://wiki.archlinux.org/title/Picom#dwm_and_dmenu
      focus-exclude = "x = 0 && y = 0 && override_redirect = true";

      blur-background-exclude = [
        "class_g != 'kitty' && class_g != 'dmenu' && class_g != 'Rofi'"
      ];

      fade-exclude = [
        "_NET_WM_STATE *= '_NET_WM_STATE_FULLSCREEN'"
      ];

      unredir-if-possible-exclude = [ "class_g = 'mpv'" "class_g = 'Firefox'" ];

      log-level = "warn";
      log-file = "${config.home.homeDirectory}/.cache/picom-log.log";
      show-all-xerrors = true;
    };

    extraConfig = ''
      animations = ({
        # Window spawn (open/show)
        triggers = ["open", "show"];
        preset = "appear";
        curve = "cubic-bezier(0.25, 0.46, 0.45, 0.94)";
      }, {
        # Window close/hide
        triggers = ["close", "hide"];
        preset = "disappear";
        curve = "cubic-bezier(0.55, 0.06, 0.68, 0.19)";
      });

      # Preset refinements for macOS fidelity
      appear = {
          *knobs = { scale = 0.9; duration = 0.24; };
          scale-x = { curve = "cubic-bezier(0.25, 0.46, 0.45, 0.94)"; };
          opacity = { duration = 0.16; start = 0.85; end = 1.0; };
      };

      disappear = {
          *knobs = { scale = 0.9; duration = 0.18; };
          scale-x = { curve = "cubic-bezier(0.55, 0.06, 0.68, 0.19)"; };
          opacity = { duration = 0.12; start = 1.0; end = 0.8; };
      };

      fly-out = {
          *knobs = { duration = 0.18; };
          v-timing = { curve = "cubic-bezier(0.4, 0, 0.2, 1)"; };
          opacity = { start = 1.0; end = 0.7; };
      };

      fly-in = {
          *knobs = { duration = 0.2; };
          v-timing = { curve = "cubic-bezier(0.42, 0, 0.58, 1)"; };
          opacity = { start = 0.7; end = 1.0; };
      };

      slide-in = {
          *knobs = { duration = 0.22; };
          v-timing = { curve = "cubic-bezier(0.0, 0, 0.2, 1)"; };
          opacity = { start = 0.9; end = 1.0; };
      };

      slide-out = {
          *knobs = { duration = 0.22; };
          v-timing = { curve = "cubic-bezier(0.4, 0, 0.2, 1)"; };
          opacity = { start = 1.0; end = 0.9; };
      };
    '';
  };
}
