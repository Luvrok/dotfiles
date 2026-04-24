{ fontSize, ... }:

{
  # todo: source http proxy
  programs.kitty = {
    enable = true;
    shellIntegration.mode = "no-rc no-cursor";
    themeFile = "gruvbox-dark";
    settings = {
      font_family = "JetBrainsMonoNL Nerd Font";
      font_size = "${toString fontSize}.0";

      clear_all_shortcuts = "yes";

      background_opacity = "0.98";

      window_padding_width = 2.5;
      confirm_os_window_close = 0;

      background = "#171717";

      enable_audio_bell = "no";
      visual_bell_duration = "0";
      bell_on_tab = "no";

      symbol_map = "U+0025 JetBrains Mono";

      cursor_trail = 1;
      cursor_trail_decay = "0.45 0.45";
      cursor_shape = "block";
      cursor_blink_interval = 0.5;

      cursor = "#ebdbb2";
      cursor_text_color = "#ebdbb2";
    };

    keybindings = {
      "ctrl+c" = "copy_or_interrupt";
      "ctrl+shift+c" = "copy_to_clipboard";
      "ctrl+v" = "paste_from_clipboard";
      "ctrl+q" = "exit";
    };
  };
}
