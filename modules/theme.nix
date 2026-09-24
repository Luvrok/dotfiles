# Single source of colors and fonts (gruvbox dark).
{ lib, ... }:

{
  options.galaxy.theme = {
    colors = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {
        black = "#020202";
        bg = "#171717"; # darker than gruvbox, main background
        bg0_h = "#1d2021";
        bg0 = "#282828";
        bg1 = "#3c3836";
        bg2 = "#504945";
        gray = "#928374";
        fg4 = "#a89984";
        fg3 = "#bdae93";
        fg2 = "#d5c4a1";
        fg = "#ebdbb2";
        fg0 = "#fbf1c7";

        red = "#cc241d";
        green = "#98971a";
        yellow = "#d79921";
        blue = "#458588";
        purple = "#b16286";
        aqua = "#689d6a";
        orange = "#d65d0e";

        brightRed = "#fb4934";
        brightGreen = "#b8bb26";
        brightYellow = "#fabd2f";
        brightBlue = "#83a598";
        brightPurple = "#d3869b";
        brightAqua = "#8ec07c";
      };
    };

    font = lib.mkOption {
      type = lib.types.str;
      default = "JetBrainsMonoNL Nerd Font";
    };
  };
}
