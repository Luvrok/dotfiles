{ ... }:

{
  programs.zathura = {
    enable = true;

    options = {
      font = "JetBrainsMonoNL Nerd Font 14";
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
      default-bg = "#1d2021";
      statusbar-bg = "#1d2021";
      notification-bg = "#1d2021";
      inputbar-bg = "#1d2021";
      render-loading-bg = "#1d2021";
      index-active-bg = "#1d2021";

      default-fg = "#ebdbb2";

      completion-bg = "#1d2021";
      completion-fg = "#ebdbb2";
      completion-highlight-bg = "#3c3836";
      completion-highlight-fg = "#ebdbb2";
      completion-group-bg = "#1d2021";
      completion-group-fg = "#fbf1c7";

      statusbar-fg = "#ebdbb2";

      notification-fg = "#ebdbb2";
      notification-error-bg = "#282828";
      notification-error-fg = "#cc241d";
      notification-warning-bg = "#282828";
      notification-warning-fg = "#d79921";

      inputbar-fg = "#ebdbb2";

      index-fg = "#ebdbb2";
      index-bg = "#1d2021";
      index-active-fg = "#ebdbb2";

      render-loading-fg = "#ebdbb2";

      highlight-color = "#1d2021";
      highlight-fg = "#d65d0e";
      highlight-active-color = "#d65d0e";

      # Перекраска содержимого документа
      recolor = "true";
      recolor-lightcolor = "#1d2021";
      recolor-darkcolor = "#d5c4a1";
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
}
