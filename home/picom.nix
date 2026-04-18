{ config, pkgs, ... }:

{
  services.picom = {
    enable = true;
    backend = "glx";
    vSync = true;

    package = pkgs.picom;

    opacityRules = [
      "100:class_g = 'kitty' && focused"
      "95:class_g = 'kitty' && !focused"
      "100:class_g = 'librewolf' && focused"
      "95:class_g = 'librewolf' && !focused"
      "100:class_g = 'obsidian' && focused"
      "95:class_g = 'obsidian' && !focused"
      "98:class_g = 'TelegramDesktop' && focused"
      "95:class_g = 'TelegramDesktop' && !focused"
      "98:class_g = 'Element' && focused"
      "95:class_g = 'Element' && !focused"
      "98:class_g = 'qBittorrent' && focused"
      "95:class_g = 'qBittorrent' && !focused"
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
        "class_g != 'kitty' && class_g != 'dmenu' && class_g != 'Rofi' && class_g != 'spterm' && class_g != 'qBittorrent' && class_g != 'Element' && class_g != 'TelegramDesktop' && class_g != 'obsidian'"
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
