{ config, lib, ... }:

let
  c = config.galaxy.theme.colors;
  inherit (config.galaxy.theme) font;
  inherit (config.galaxy.host) fontSize;

  urgency = fg: {
    timeout = "4";
    foreground = fg;
    background = c.bg0;
    frame_color = c.orange;
    highlight_color = "#292929";
    indicator_color = c.fg0;
    progress_color = "#00ff00";
  };
in
{
  options.galaxy.desktop.dunst.enable = lib.mkEnableOption "dunst";

  config = lib.mkIf config.galaxy.desktop.dunst.enable {
    home-manager.users.${config.galaxy.host.user}.services.dunst = {
      enable = true;
      settings = {
        experimental = {
          per_monitor_dpi = false;
        };

        global = {
          width = 280;
          origin = "bottom-center";
          monitor = "0";
          follow = "mouse";
          indicate_hidden = "no";
          shrink = "yes";
          separator_height = "1";
          padding = "12";
          horizontal_padding = "20";
          frame_width = "1";
          sort = "no";
          idle_threshold = "120";
          font = "${font} ${toString fontSize}";
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
          history_length = "10";
          always_run_script = "true";
          title = "Dunst";
          class = "Dunst";
          highlight = c.fg;
        };

        shortcuts = {
          close = "ctrl+space";
          close_all = "ctrl+shift+space";
          history = "ctrl+grave";
          context = "ctrl+shift+period";
        };

        urgency_low = urgency c.fg;
        urgency_normal = urgency c.fg0;
        urgency_critical = urgency c.fg0;
      };
    };
  };
}
