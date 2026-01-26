{ pkgs, ... }:

{
  enable = true;
  shellIntegration.enableZshIntegration = true;
  shellIntegration.enableBashIntegration = true;
  themeFile = "GruvboxMaterialDarkHard";
  settings = {
    font_family = "JetBrainsMonoNL Nerd Font";
    font_size = "13.0";

    background_opacity = "0.95";

    window_padding_width = 2.5;
    window_padding_height = 2.5;

    confirm_os_window_close = 0;

    background = "#171717";

    enable_audio_bell = "no";
    visual_bell_duration = "0";
    bell_on_tab = "no";

    symbol_map = "U+0025 JetBrains Mono";
  };

  keybindings = {
    "ctrl+c" = "copy_or_interrupt";
    "ctrl+shift+c" = "copy_to_clipboard";
    "ctrl+v" = "paste_from_clipboard";
    "ctrl+q" = "exit";
  };
}
