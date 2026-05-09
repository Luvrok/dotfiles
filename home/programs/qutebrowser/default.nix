{ ... }:

let
  cfgPath = ./config.py;
  themePath = ./gruvbox.py;
in
{
  programs.qutebrowser = {
    enable = true;
    extraConfig = builtins.readFile cfgPath;
  };

  home.file.".config/qutebrowser/gruvbox.py".source = themePath;
}
