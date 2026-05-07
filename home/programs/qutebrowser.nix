{ pkgs, ... }:

let
  bgDefault = "#282828";
  bgSelected = "#d65d0e";
  fgDefault = "#ebdbb2";
  fgSelected = "#ebdbb2";
in
{
  programs.qutebrowser = {
    enable = true;

    keyBindings = {
      normal = {
        "<Ctrl-m>" = "hint links spawn ${pkgs.mpv}/bin/mpv -volume=30 {hint-url}";
        "<Ctrl-Shift-m>" = "spawn ${pkgs.mpv}/bin/mpv -volume=30 {url}";
      };
    };

    settings = {
      qt.args = [];

      content = {
        autoplay = false;
        pdfjs = true;
        notifications.presenter = "libnotify";
      };
      hints = {
        border = "1px solid #d65d0e";
      };
      colors = {
        tabs = {
          bar.bg = bgDefault;
          even = {
            bg = bgDefault;
            fg = fgDefault;
          };
          odd = {
            bg = bgDefault;
            fg = fgDefault;
          };
          selected.even = {
            bg = bgSelected;
            fg = fgDefault;
          };
          selected.odd = {
            bg = bgSelected;
            fg = fgDefault;
          };
        };
        hints = {
          bg = bgDefault;
          fg = fgDefault;
          match.fg = fgSelected;
        };
        completion = {
          fg = fgDefault;
          match.fg = fgSelected;
          category = {
            bg = bgDefault;
            fg = fgDefault;
            border = {
              top = bgDefault;
              bottom = bgDefault;
            };
          };
          even.bg = bgDefault;
          odd.bg = bgDefault;
          item = {
            selected = {
              bg = bgSelected;
              fg = fgDefault;
              match.fg = fgSelected;
              border = {
                top = bgSelected;
                bottom = bgSelected;
              };
            };
          };
        };
        statusbar = {
          caret = {
            bg = bgDefault;
            fg = fgDefault;

            selection = {
              bg = bgDefault;
              fg = fgSelected;
            };
          };
          command = {
            bg = bgDefault;
            fg = fgSelected;

            private = {
              bg = bgDefault;
              fg = fgSelected;
            };
          };

          insert = {
            bg = bgDefault;
            fg = fgSelected;
          };

          normal = {
            bg = bgDefault;
            fg = fgSelected;
          };

          passthrough = {
            bg = bgDefault;
            fg = fgSelected;
          };

          private = {
            bg = bgDefault;
            fg = fgSelected;
          };

          progress.bg = bgDefault;

          url = {
            error.fg = "#cc241d";
            fg = fgDefault;
            hover.fg = fgSelected;

            success = {
              http.fg = fgDefault;
              https.fg = fgDefault;
            };

            warn.fg = fgDefault;
          };
        };
      };
      fonts = {
        default_size = "11pt";
        default_family = "JetBrainsMono Nerd Font Mono";
        contextmenu = "default_size default_family";
      };
    };

    extraConfig = ''
      c.tabs.padding = { "top": 4, "bottom": 4, "left": 5, "right": 5 }
    '';
  };
}
