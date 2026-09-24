{ config, lib, ... }:

let
  c = config.galaxy.theme.colors;
in
{
  options.galaxy.programs.zathura.enable = lib.mkEnableOption "zathura";

  config = lib.mkIf config.galaxy.programs.zathura.enable {
    home-manager.users.${config.galaxy.host.user} = {
      programs.zathura = {
        enable = true;

        options = {
          font = "${config.galaxy.theme.font} 14";
          selection-clipboard = "clipboard";
          adjust-open = "best-fit";
          pages-per-row = "1";
          scroll-page-aware = "true";
          scroll-full-overlap = "0.01";
          scroll-step = "100";
          zoom-min = "60";
          guioptions = "none";
          statusbar-h-padding = "0";
          statusbar-v-padding = "0";

          # UI
          default-bg = c.bg0_h;
          statusbar-bg = c.bg0_h;
          notification-bg = c.bg0_h;
          inputbar-bg = c.bg0_h;
          render-loading-bg = c.bg0_h;
          index-active-bg = c.bg0_h;

          default-fg = c.fg;

          completion-bg = c.bg0_h;
          completion-fg = c.fg;
          completion-highlight-bg = c.bg1;
          completion-highlight-fg = c.fg;
          completion-group-bg = c.bg0_h;
          completion-group-fg = c.fg0;

          statusbar-fg = c.fg;

          notification-fg = c.fg;
          notification-error-bg = c.bg0;
          notification-error-fg = c.red;
          notification-warning-bg = c.bg0;
          notification-warning-fg = c.yellow;

          inputbar-fg = c.fg;

          index-fg = c.fg;
          index-bg = c.bg0_h;
          index-active-fg = c.fg;

          render-loading-fg = c.fg;

          highlight-color = c.bg0_h;
          highlight-fg = c.orange;
          highlight-active-color = c.orange;

          # Перекраска содержимого документа
          recolor = "true";
          recolor-lightcolor = c.bg0_h;
          recolor-darkcolor = c.fg2;
          recolor-keephue = "true";
        };

        mappings = {
          u = "scroll half-up";
          d = "scroll half-down";
          D = "toggle_page_mode";
          r = "reload";
          R = "rotate";
          K = "zoom in";
          J = "zoom out";
          i = "recolor";
          p = "print";
          g = "goto top";

          # Custom mappings for fullscreen mode.
          "[fullscreen] u" = "scroll half-up";
          "[fullscreen] d" = "scroll half-down";
          "[fullscreen] D" = "toggle_page_mode";
          "[fullscreen] r" = "reload";
          "[fullscreen] R" = "rotate";
          "[fullscreen] K" = "zoom in";
          "[fullscreen] J" = "zoom out";
          "[fullscreen] i" = "recolor";
          "[fullscreen] p" = "print";
          "[fullscreen] g" = "goto top";
        };
      };
    };
  };
}
