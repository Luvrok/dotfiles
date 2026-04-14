{ config, pkgs, ... }:

{
  services.picom = {
    enable = true;
    backend = "glx";
    vSync = true;

    package = pkgs.picom;

    opacityRules = [
      "100:class_g = 'kitty' && focused"
      "91:class_g = 'kitty' && !focused"
    ];

    settings = {
      dbus = false;

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

      blur-background-exclude = [
        "class_g != 'kitty' && class_g != 'dmenu' && class_g != 'Rofi' && class_g != 'spterm'"
      ];

      fade-exclude = [
        "_NET_WM_STATE *= '_NET_WM_STATE_FULLSCREEN'"
      ];

      unredir-if-possible = true;
      unredir-if-possible-exclude = [
        "class_g = 'mpv'"
        "class_g = 'librewolf'"
      ];

      log-level = "warn";
      log-file = "${config.home.homeDirectory}/.cache/picom-log.log";
      show-all-xerrors = true;
    };
  };
}
