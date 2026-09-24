{
  config,
  lib,
  pkgs,
  ...
}:

let
  c = config.galaxy.theme.colors;

  theme = pkgs.writeText "kitty-theme.conf" ''
    include ${pkgs.kitty-themes}/share/kitty-themes/themes/gruvbox-dark.conf

    background ${c.bg}
    cursor ${c.fg}
    cursor_text_color ${c.fg}
    font_family ${config.galaxy.theme.font}
    font_size ${toString config.galaxy.host.fontSize}.0
  '';
in
{
  options.galaxy.programs.kitty.enable = lib.mkEnableOption "kitty";

  config = lib.mkIf config.galaxy.programs.kitty.enable {
    environment.variables.TERMINAL = "kitty";

    environment.systemPackages = [
      pkgs.kitty
      # Remote hosts don't know xterm-kitty.
      pkgs.ssh-term-fix
    ];

    galaxy.files.home = {
      ".config/kitty/kitty.conf" = ./config/kitty.conf;
      ".config/kitty/theme.conf" = theme;
    };

    home-manager.users.${config.galaxy.host.user}.programs.zsh.initContent = ''
      if test -n "$KITTY_INSTALLATION_DIR"; then
        export KITTY_SHELL_INTEGRATION="no-rc no-cursor"
        autoload -Uz -- "$KITTY_INSTALLATION_DIR"/shell-integration/zsh/kitty-integration
        kitty-integration
        unfunction kitty-integration
      fi
    '';
  };
}
