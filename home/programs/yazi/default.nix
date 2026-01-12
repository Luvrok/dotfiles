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
        image_filter = "triangle"; # way faster than lanczos3, with no visible loss in image quality (if image_quality have high value).
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
