{ pkgs, lib, ... }:

{
  services.displayManager.ly = {
    enable = true;
    settings = {
      animation = "dur_file";
      # animation = "doom";
      dur_file_path = builtins.toString ./blackhole.dur;
      full_color = true;
      bigclock_seconds = true;
      lang = "en";

      bg = "0x00000000"; # почти чёрный / очень тёмный gruvbox bg
      fg = "0x00EBDBB2"; # светлый текст
      border_fg = "0x00D65D0E"; # оранжевый бордер

      # doom_fire_height = 5; # высота пламени (1-9)
      # doom_fire_spread = 2; # разброс (0-4)
      # doom_top_color = "0x009F2707"; # низкие языки (тёмно-красный)
      # doom_middle_color = "0x00D65D0E"; # средние (твой оранжевый)
      # doom_bottom_color = "0x00FFFC00"; # яркие у основания (жёлтый/белый)

      blank_box = true;
      clear_password = true;
      default_input = "password";
      hide_version_string = true;
      input_len = 34;
      show_tty = false;
      vi_default_mode = "insert";
      x_vt = "null";
      initial_info_text = "Arise now, ye Tarnished.";
    };
  };
}
