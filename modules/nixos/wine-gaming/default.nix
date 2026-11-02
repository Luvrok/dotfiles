# wine for games, apart from everything else: its own prefix, so a game's
# dll overrides and winetricks never touch another prefix (~/.wine, vinegar's,
# steam's). the commands are wine-games and winetricks-games, both use the
# same prefix. off until the host sets dotfiles.wine-gaming.enable
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.wine-gaming;

  # the prefix is per user, so it's made at the first run, not at build time
  env = ''
    export WINEPREFIX="''${WINE_GAMES_PREFIX:-''${XDG_DATA_HOME:-$HOME/.local/share}/wine-games}"
    export WINEARCH=win64
    export WINEDEBUG="''${WINEDEBUG:--all}"
    # no winemenubuilder: it fills ~/.local/share/applications with junk
    export WINEDLLOVERRIDES="''${WINEDLLOVERRIDES:-winemenubuilder.exe=d}"
  '';

  wine-games = pkgs.writeShellApplication {
    name = "wine-games";
    runtimeInputs = [ cfg.package ];
    text = ''
      ${env}
      exec wine "$@"
    '';
  };

  winetricks-games = pkgs.writeShellApplication {
    name = "winetricks-games";
    runtimeInputs = [
      cfg.package
      pkgs.winetricks
    ];
    text = ''
      ${env}
      exec winetricks "$@"
    '';
  };
in
{
  options.dotfiles.wine-gaming = {
    enable = lib.mkEnableOption "wine for games, in its own prefix";
    package = lib.mkOption {
      type = lib.types.package;
      # staging: the patches games ask for, wow64: 32 bit games without the
      # 32 bit libraries of the system
      default = pkgs.wineWow64Packages.staging;
      defaultText = lib.literalExpression "pkgs.wineWow64Packages.staging";
      description = "the wine of the games";
    };
  };

  config = lib.mkIf cfg.enable {
    # vulkan for dxvk and vkd3d-proton, the amd and nvidia modules set it too
    hardware.graphics = {
      enable = true;
      enable32Bit = true;
    };

    environment.systemPackages = [
      wine-games
      winetricks-games
    ];
  };
}
