{ pkgs, config, lib, ... }:

# references
# docs -> yazi-rs.github.io/docs/
# 1(nix) -> https://github.com/sk1lax/bspwm-dots/blob/42a2271cf99195d30f20c7144dad75bee1f1adc6/config/yazi/yazi.toml
# yatline-githead -> https://github.com/imsi32/yatline-githead.yazi

let
  inherit (lib) getExe;
in
{
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;

    plugins = {
      inherit (pkgs.yaziPlugins) full-border;
      inherit (pkgs.yaziPlugins) smart-enter;
      # inherit (pkgs.yaziPlugins) yatline-githead; # wait when this pr will be merge https://github.com/imsi32/yatline-githead.yazi/pull/7
      # inherit (pkgs.yaziPlugins) git; # dont work, maybe bcs nixos i think (todo: figure it out)
      xclip-system-clipboard = pkgs.fetchFromGitHub {
        owner = "seqizz";
        repo = "xclip-system-clipboard.yazi";
        rev = "67f63710c892e9443c81df8dd396b93ff658a9ba";
        hash = "sha256-+jzVFosUjNHKAdOrRz4HXNweFggUoWoGMtYv2L3GYyA=";
      };
      yatline = pkgs.fetchFromGitHub {
        owner = "imsi32";
        repo = "yatline.yazi";
        rev = "3227a30b21f69b68df513754b5a00d6e75cece57";
        hash = "sha256-yhptHABQ0alVab2i367D5grJyG7SrfHH8H4JuGeYFyk=";
      };
      yatline-gruvbox = pkgs.fetchFromGitHub {
        owner = "imsi32";
        repo = "yatline-gruvbox.yazi";
        rev = "1ce46ebe1f48139de30051638d7c6ba71d867220";
        hash = "sha256-Dsf6FlUmGQTLSM63++Wa9ChQmTqhAp03rIWYtS1rrv8=";
      };
    };

    initLua = ./init.lua;

    # cant disable icons when yatline is enable looks like this bug(but its not):
    # https://github.com/imsi32/yatline.yazi/issues/61
    # theme = {
    #   prepend_rules = true;
    #   icon = {
    #     globs = [];
    #     dirs  = [];
    #     files = [];
    #     exts  = [];
    #     conds = [];
    #   };
    # };

    keymap = {
      input = {
        prepend_keymap = [
          # https://yazi-rs.github.io/docs/tips#close-input-by-esc
          {
            on = ["<Esc>"];
            run = "close";
            desc = "Cancel input";
          }
        ];
      };
      mgr = {
        prepend_keymap = [
          {
            on = ["d" "d"];
            run = "remove --permanently";
            desc = "Delete permanently";
          }
          {
            on = ["m" "k"];
            run = "create --dir";
            desc = "Create directory";
          }
          {
            on = ["r"];
            run = "rename";
            desc = "Rename";
          }
          {
            on = ["c" "p"];
            run = "yank";
            desc = "Copy (toggle)";
          }
          {
            on = ["d" "c"];
            run = "yank --cut";
            desc = "Cut (toggle)";
          }
          {
            on = ["."];
            run = "toggle hidden";
            desc = "Toggle hidden files";
          }
          {
            on = ["p" "p"];
            run = "paste";
            desc = "Paste";
          }
          {
            on = [ "u" "u" ];
            run = ''shell --confirm 'unzip "$1"' '';
            desc = "Unzip file";
          }
          {
            on = ["d" "l"];
            run = "link --relative";
            desc = "link file";
          }
          {
            on = ["<Enter>"];
            run = "plugin --sync smart-enter";
            desc = "Enter directory";
          }
          {
            on = ["<Right>"];
            run = "plugin --sync smart-enter";
            desc = "Enter directory";
          }
          {
            on = ["y"];
            run = "plugin xclip-system-clipboard";
          }
          {
            on = ["<C-n>"];
            run = ''shell -- ${getExe pkgs.dragon-drop} -x -T -i -s 128 "$0"'';
          }
        ];
      };
    };

    settings = {
      mgr = {
        ratio = [
          1
          3
          4
        ];
        sort_by = "natural";
        # linemode = "size"; # folder count works so bad
        show_hidden = false;
        show_symlink = true;
      };
      opener = {
        edit = [
          {
            run = ''nvim "$@"'';
            block = true;
          }
        ];
      };
      preview = {
        cache_dir = "${config.xdg.cacheHome}/yazi/preview-cache";
        tab_size = 2;
        max_width = 1920;
        image_filter = "lanczos3";
        image_delay = 30;
        image_quality = 90;
        wrap = "yes";
      };
      tasks = {
        macro_workers = 2;
        image_alloc = 268435456; # 256MB
        image_bound = [0 0];
        suppress_preload = true;
      };
    };
    flavors = {
      gruvbox-dark = ./gruvbox-dark.yazi;
    };
    theme = {
      flavor = {
        use = "gruvbox-dark";
        dark = "gruvbox-dark";
      };
    };
  };
}
