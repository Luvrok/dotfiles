{
  pkgs,
  config,
  lib,
  ...
}:

let
  inherit (lib) getExe;
  yatline-gruvbox = pkgs.fetchFromGitHub {
    owner = "imsi32";
    repo = "yatline-gruvbox.yazi";
    rev = "1ce46ebe1f48139de30051638d7c6ba71d867220";
    hash = "sha256-Dsf6FlUmGQTLSM63++Wa9ChQmTqhAp03rIWYtS1rrv8=";
  };
  bunny = pkgs.fetchFromGitHub {
    owner = "stelcodes";
    repo = "bunny.yazi";
    rev = "71b14a3d624572f4884354c2e218296e9ece07cc";
    hash = "sha256-uQO0C00yOFPWq8KEO/kEZM6tFZRc9SiXfgN7kzlwDeA=";
  };
in
{
  programs.yazi = {
    enable = true;
    enableBashIntegration = true;
    enableZshIntegration = true;

    extraPackages = with pkgs; [
      sox
    ];

    plugins = {
      inherit (pkgs.yaziPlugins) full-border;
      inherit (pkgs.yaziPlugins) smart-enter;
      inherit (pkgs.yaziPlugins) jump-to-char;
      inherit (pkgs.yaziPlugins) smart-filter;
      inherit (pkgs.yaziPlugins) yatline;
      inherit (pkgs.yaziPlugins) githead;
      inherit (pkgs.yaziPlugins) clipboard;

      inherit bunny;
      inherit yatline-gruvbox;

      # todo:
      # vcs-files
      # chmod
      # augment-command
    };

    initLua = ./init.lua;

    keymap = {
      input = {
        prepend_keymap = [
          # https://yazi-rs.github.io/docs/tips#close-input-by-esc
          {
            on = [ "<Esc>" ];
            run = "close";
            desc = "Cancel input";
          }
        ];
      };
      mgr = {
        prepend_keymap = [
          {
            on = [
              "d"
              "d"
            ];
            run = "remove --permanently";
            desc = "Delete permanently";
          }
          {
            on = [
              "m"
              "k"
            ];
            run = "create --dir";
            desc = "Create directory";
          }
          {
            on = [
              "r"
              "r"
            ];
            run = "rename";
            desc = "Rename";
          }
          {
            on = [
              "c"
              "p"
            ];
            run = "yank";
            desc = "Copy (toggle)";
          }
          {
            on = [
              "c"
              "t"
            ];
            run = "yank --cut";
            desc = "Cut (toggle)";
          }
          {
            on = [ "." ];
            run = "hidden toggle";
            desc = "Toggle hidden files";
          }
          {
            on = [
              "p"
              "p"
            ];
            run = "paste";
            desc = "Paste";
          }
          {
            on = [
              "u"
              "u"
            ];
            run = ''shell --confirm 'unzip "$1"' '';
            desc = "Unzip file";
          }
          {
            on = [
              "d"
              "l"
            ];
            run = "link --relative";
            desc = "link file";
          }
          {
            on = [ "<C-f>" ];
            run = "find";
            desc = "Find";
          }
          # some plugins keymaps
          {
            on = [
              "f"
              "s"
            ];
            run = "plugin smart-filter";
            desc = "Smart filter";
          }
          {
            on = [
              "f"
              "j"
            ];
            run = "plugin jump-to-char";
            desc = "Jump to char";
          }
          {
            on = [ "<Enter>" ];
            run = "plugin --sync smart-enter";
            desc = "Enter directory";
          }
          {
            on = [ "<Right>" ];
            run = "plugin --sync smart-enter";
            desc = "Enter directory";
          }
          {
            on = [ "l" ];
            run = "plugin --sync smart-enter";
            desc = "Enter directory";
          }
          {
            on = [
              "d"
              "r"
            ];
            run = ''shell -- ${getExe pkgs.dragon-drop} -x -T -i -s 128 "$0"'';
          }
          # clipboard.yazi
          {
            on = [
              "c"
              "c"
            ];
            run = [
              "yank"
              "plugin clipboard -- --action=copy"
            ];
            desc = "Yank selected files (copy)";
          }
          # nvim
          {
            on = [
              "n"
              "n"
            ];
            run = "shell --block -- ${getExe pkgs.neovim} .";
            desc = "nvim new";
          }
          # bookmarks
          {
            on = ";";
            run = "plugin bunny";
            desc = "Start bunny.yazi";
          }
          {
            on = "'";
            run = "plugin bunny fuzzy";
            desc = "Start bunny.yazi fuzzy";
          }
          # terminal with nvim
          {
            on = [
              "n"
              "t"
            ];
            run = "shell --orphan -- ${getExe pkgs.kitty} -e ${getExe pkgs.neovim} .";
            desc = "nvim new terminal";
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
        mouse_events = [
          "click"
          "scroll"
          "touch"
          "move"
          "drag"
        ];
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
        image_bound = [
          0
          0
        ];
        suppress_preload = true;
      };
    };
    flavors = {
      gruvbox-dark = ./gruvbox-dark.yazi;
    };
    theme = {
      indicator.preview = {
        underline = false;
      };
      icon = {
        globs = [ ];
        dirs = [ ];
        files = [ ];
        exts = [ ];
        conds = [ ];
      };
      flavor = {
        use = "gruvbox-dark";
        dark = "gruvbox-dark";
      };
    };
  };
}
