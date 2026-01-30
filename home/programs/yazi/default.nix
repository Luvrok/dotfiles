{ pkgs, config, lib, ... }:

let
  inherit (lib) getExe;
  xclip-system-clipboard = pkgs.fetchFromGitHub {
    owner = "seqizz";
    repo = "xclip-system-clipboard.yazi";
    rev = "67f63710c892e9443c81df8dd396b93ff658a9ba";
    hash = "sha256-+jzVFosUjNHKAdOrRz4HXNweFggUoWoGMtYv2L3GYyA=";
  };
  yatline = pkgs.fetchFromGitHub {
    owner = "imsi32";
    repo = "yatline.yazi";
    rev = "c5d4b487d6277dd68ea9d3c6537641bf4ae9cf8e";
    hash = "sha256-HjTRAfUHs6vlEWKruQWeA2wT/Mcd+WEHM90egFTYcWQ=";
  };
  githead = pkgs.fetchFromGitHub {
    owner = "llanosrocas";
    repo = "githead.yazi";
    rev = "317d09f728928943f0af72ff6ce31ea335351202";
    hash = "sha256-o2EnQYOxp5bWn0eLn0sCUXcbtu6tbO9pdUdoquFCTVw=";
  };
  yatline-gruvbox = pkgs.fetchFromGitHub {
    owner = "imsi32";
    repo = "yatline-gruvbox.yazi";
    rev = "1ce46ebe1f48139de30051638d7c6ba71d867220";
    hash = "sha256-Dsf6FlUmGQTLSM63++Wa9ChQmTqhAp03rIWYtS1rrv8=";
  };
in
{
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;

    plugins = {
      inherit (pkgs.yaziPlugins) full-border;
      inherit (pkgs.yaziPlugins) smart-enter;
      inherit (pkgs.yaziPlugins) jump-to-char;
      inherit (pkgs.yaziPlugins) smart-filter;
      inherit xclip-system-clipboard;
      inherit yatline;
      inherit githead;
      inherit yatline-gruvbox;

      # todo:
      # vcs-files
      # smart-filter
      # chmod
      # augment-command
    };

    initLua = ./init.lua;

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
            on = ["<C-f>"];
            run = "find";
            desc = "Find";
          }
          # some plugins keymaps
          {
            on = ["F"];
            run = "plugin smart-filter";
            desc = "Smart filter";
          }
          {
            on = ["f"];
            run = "plugin jump-to-char";
            desc = "Jump to char";
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
        # linemode = "size"; # folder count works so bad, git plugin also dont work at all
        show_hidden = false;
        show_symlink = true;
        mouse_events = ["click" "scroll" "touch" "move" "drag"];
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
      indicator.preview = { underline = false; };
      icon = {
        globs = [];
        dirs  = [];
        files = [];
        exts  = [];
        conds = [];
      };
      flavor = {
        use = "gruvbox-dark";
        dark = "gruvbox-dark";
      };
    };
  };
}
