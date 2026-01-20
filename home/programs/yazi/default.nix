{ pkgs, config, lib, ... }:
let
  inherit (lib) getExe;
in
{
  programs.yazi = {
    enable = true;
    package = pkgs.yazi;

    plugins = {
      inherit (pkgs.yaziPlugins) full-border;
      inherit (pkgs.yaziPlugins) smart-enter;
      xclip-system-clipboard = pkgs.fetchFromGitHub {
        owner = "seqizz";
        repo = "xclip-system-clipboard.yazi";
        rev = "67f63710c892e9443c81df8dd396b93ff658a9ba";
        hash = "sha256-+jzVFosUjNHKAdOrRz4HXNweFggUoWoGMtYv2L3GYyA=";
      };
    };

    initLua = ''
      require("full-border"):setup()
    '';

    theme = {
      icon = {
        globs = [];
        dirs  = [];
        files = [];
        exts  = [];
        conds = [];
      };
    };

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
          # https://yazi-rs.github.io/docs/tips#smart-enter
          {
            on = ["<Enter>"];
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
        linemod = "none";
        show_hidden = false;
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
