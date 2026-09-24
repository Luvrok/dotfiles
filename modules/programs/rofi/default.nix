# rofi: package, config/*.rasi (colors.rasi and font.rasi are generated), base scripts.
# Feature menus with their own dependencies live in ../rofi-*.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.galaxy.lib) hexToRgb;
  c = config.galaxy.theme.colors;
  mkScript = config.galaxy.lib.mkScript pkgs;

  colors = pkgs.writeText "colors.rasi" ''
    * {
        BG:    rgb(${hexToRgb c.bg}, 0.9); /* background */
        BGA:   rgb(${hexToRgb c.bg0}, 0.9); /* background alternate */
        FG:    ${c.fg}; /* foreground (main text) */
        FGA:   ${c.fg}; /* foreground accent (error/warning) */
        BDR:   ${c.orange}; /* border */
        SEL:   ${c.fg0}; /* selection */
        SELBG: rgb(${hexToRgb c.orange}); /* selection background */
    }
  '';

  font = pkgs.writeText "font.rasi" ''
    * {
        font:  "${config.galaxy.theme.font} ${toString config.galaxy.host.fontSize}";
    }
  '';

  scripts = {
    rofi-menu = with pkgs; [
      rofi
      dmenu # dmenu_path
      coreutils
      gawk
      gnugrep
      gnused
    ];
    rofi-powermenu = with pkgs; [
      rofi
      procps
    ];
    rofi-killer = with pkgs; [
      rofi
      procps
    ];
    rofi-askpass = [ pkgs.rofi ];
  };
in
{
  options.galaxy.programs.rofi.enable = lib.mkEnableOption "rofi";

  config = lib.mkIf config.galaxy.programs.rofi.enable {
    environment.systemPackages = lib.mapAttrsToList (
      name: runtimeInputs:
      mkScript {
        inherit name runtimeInputs;
        src = ./scripts/${name};
      }
    ) scripts;

    galaxy.files.home = config.galaxy.lib.linkTree ".config/rofi" ./config // {
      ".config/rofi/colors.rasi" = colors;
      ".config/rofi/font.rasi" = font;
    };

    home-manager.users.${config.galaxy.host.user}.programs.rofi = {
      enable = true;
      package = pkgs.rofi;
      plugins = with pkgs; [ rofi-calc ];
      terminal = "${pkgs.kitty}/bin/kitty";
      extraConfig = {
        kb-accept-entry = "Control+m,Return,KP_Enter";
        kb-remove-to-eol = "";
        kb-row-down = "Down,Control+n,Control+j";
        kb-row-up = "Up,Control+p,Control+k";
      };
    };
  };
}
