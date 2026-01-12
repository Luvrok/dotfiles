{ config, lib, pkgs, ... }:

{
  programs.ranger = {
    enable = false;
    package = pkgs.ranger;

    settings = {
      preview_images_method = "ueberzug";
      use_preview_script  = true;
      preview_images  = true;
      preview_files  = true;
      open_all_images  = true;
      draw_borders  = true;
      hidden_filter  = ''^\.|\.(bak|swp)$|^lost\+found$|^__pycache__$'';
      nested_ranger_warning  = true;
      colorscheme  = "solarized";
      autoupdate_cumulative_size = true;
    };

    extraConfig = ''
      map . set show_hidden!
      map dd console delete
      map dt cut mode=toggle
      map yt copy mode=toggle
      map pp paste
      map cw console rename%space
      map r    reload_cwd
      # default_linemode devicons2

      map v shell nvim %s
      map a mark
      map A unmark
      map nf console mkdir%space
      map uu shell unzip %f

      map V mark_files toggle=True

      # Sorting
      map cr set sort_reverse!
      map cz set sort=random
      map cs chain set sort=size;      set sort_reverse=False
      map cb chain set sort=basename;  set sort_reverse=False
      map cn chain set sort=natural;   set sort_reverse=False
      map cm chain set sort=mtime;     set sort_reverse=False
      map cc chain set sort=ctime;     set sort_reverse=False
      map ca chain set sort=atime;     set sort_reverse=False
      map ct chain set sort=type;      set sort_reverse=False
      map ce chain set sort=extension; set sort_reverse=False
    '';

    plugins = [
      {
        name = "ranger-archives";
        src = builtins.fetchGit {
          url = "https://github.com/maximtrp/ranger-archives";
          ref = "master";
          rev = "b4e136b24fdca7670e0c6105fb496e5df356ef25";
        };
      }
    ];
  };
}
