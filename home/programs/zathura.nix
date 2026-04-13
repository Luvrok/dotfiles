{ ... }:

{
  programs.zathura = {
    enable = true;
    options = {
      font = "JetBrainsMonoNL Nerd Font 14"; # Sets the font used in the UI to SF Pro Text with size 15.
      selection-clipboard = "clipboard"; # Enables copying selected text to the clipboard.
      adjust-open = "best-fit"; # Adjusts the document to fit the window when opened.
      pages-per-row = "1"; # Sets the number of pages displayed per row to 1.
      scroll-page-aware = "true"; # Enables page-aware scrolling, stopping at page boundaries.
      scroll-full-overlap = "0.01"; # Sets the overlap when scrolling a full page to 1% of the page height.
      scroll-step = "100"; # Sets the number of pixels to scroll with each step.
      zoom-min = "60"; # Sets the minimum zoom level to 10%.
      guioptions = "none"; # Disables additional GUI elements.
      statusbar-h-padding = "0"; # Sets horizontal padding of the status bar to 0.
      statusbar-v-padding = "0"; # Sets vertical padding of the status bar to 0.

      default-fg = "#ebdbb2";
      default-bg = "#282828";

      completion-bg = "#1d2021";
      completion-fg = "#ebdbb2";
      completion-highlight-bg = "#3c3836";
      completion-highlight-fg = "#ebdbb2";
      completion-group-bg = "#1d2021";
      completion-group-fg = "#fbf1c7";

      statusbar-fg = "#ebdbb2";
      statusbar-bg = "#282828";

      notification-bg = "#282828";
      notification-fg = "#ebdbb2";
      notification-error-bg = "#282828";
      notification-error-fg = "#cc241d";
      notification-warning-bg = "#282828";
      notification-warning-fg = "#d79921";

      inputbar-fg = "#ebdbb2";
      inputbar-bg = "#282828";

      recolor = "true";
      recolor-lightcolor = "#282828";
      recolor-darkcolor = "#ebdbb2";

      index-fg = "#ebdbb2";
      index-bg = "#1d2021";
      index-active-fg = "#ebdbb2";
      index-active-bg = "#282828";

      render-loading-bg = "#1d2021";
      render-loading-fg = "#ebdbb2";

      highlight-color = "#1d2021";
      highlight-fg = "#d65d0e";
      highlight-active-color = "#d65d0e";
    };

    mappings = {
      u = "scroll half-up";
      d = "scroll half-down";
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
