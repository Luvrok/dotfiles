{ config, pkgs, lib, ... }:

{
  services.dunst = {
    enable = true;
    settings = {
      experimental = {
        per_monitor_dpi = false;
      };

      global = {
        width = 300;
        origin = "bottom-center";
        monitor = "0";
        follow = "mouse";
        geometry = "350x100-15+45";
        indicate_hidden = "yes";
        shrink = "yes";
        separator_height = "1";
        padding = "12";
        horizontal_padding = "20";
        frame_width = "1";
        sort = "no";
        idle_threshold = "120";
        font = "JetBrainsMonoNL Nerd Font 14";
        line_height = "4";
        markup = "full";
        format = "%s\n%b";
        alignment = "center";
        show_age_threshold = "3000";
        word_wrap = "yes";
        ignore_newline = "no";
        transparency = "10%";
        stack_duplicates = "false";
        hide_duplicate_count = "yes";
        show_indicators = "no";
        icon_position = "left";
        max_icon_size = "32";
        sticky_history = "no";
        history_length = "20";
        always_run_script = "true";
        title = "Dunst";
        class = "Dunst";
        highlight = "#ebdbb2";
      };

      shortcuts = {
        close = "ctrl+space";
        close_all = "ctrl+shift+space";
        history = "ctrl+grave";
        context = "ctrl+shift+period";
      };

      urgency_low = {
        timeout = "4";
        foreground = "#ebdbb2";
        background = "#282828";
        frame_color = "#d65d0e";
        highlight_color = "#292929";
        separator_color = "#000";
        indicator_color = "#fbf1c7";
        progress_color = "#00ff00";
      };

      urgency_normal = {
        timeout = "4";
        foreground = "#fbf1c7";
        background = "#282828";
        frame_color = "#d65d0e";
        highlight_color = "#292929";
        separator_color = "#000";
        indicator_color = "#fbf1c7";
        progress_color = "#00ff00";
      };

      urgency_critical = {
        timeout = "4";
        foreground = "#fbf1c7";
        background = "#282828";
        frame_color = "#d65d0e";
        highlight_color = "#292929";
        separator_color = "#000";
        indicator_color = "#fbf1c7";
        progress_color = "#00ff00";
      };
    };
  };
}
