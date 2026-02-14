{ config, ... }:

{
  services.picom = {
    enable = true;
    backend = "glx";
    vSync = true;

    opacityRules = [
      "100:class_g = 'kitty' && focused"
      "90:class_g = 'kitty' && !focused"
    ];

    settings = {
      dbus = true;

      fading = true;
      fade-in-step = 0.03;
      fade-out-step = 0.03;
      fade-delta = 6;

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

      # looks better maybe
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
  };
}
