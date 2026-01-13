{ pkgs, config, ... }:

{
  programs.yazi = {
    enable = true;
    package = pkgs.yazi;

    plugins = {
      inherit (pkgs.yaziPlugins) full-border;
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
            on = ["u" "u"];
            run = "shell unzip %f";
            desc = "Unzip file";
          }
          {
            on = ["d" "l"];
            run = "link --relative";
            desc = "link file";
          }
          {
            on = [ "<Esc>" ];
            run = "unyank; unmark_all";
            desc = "Cancel yank and clear selection";
          }
          {
            on = ["<Enter>"];
            run = "open";
            desc = "Enter directory";
          }
          {
            on = ["<C-n>"];
            run = "shell -- dragon-drop -x -i -T %s1";
          }
        ];
      };
    };

    settings = {
      mgr = {
        ratio = [
          1
          2
          5
        ];
        sort_by = "natural";
        linemod = "none";
        show_hidden = false;
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
      # open.rules = [
      #   {
      #     mime = "inode/directory";
      #     use = ["reveal"];
      #   }
      # ];
      # opener = {
      #   open = [
      #     {
      #       run = ''${pkgs.xdg-utils}/bin/xdg-open "$0"'';
      #       orphan = true;
      #     }
      #   ];
      # };
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
