# Trimmed rofi-pass fork; settings in config.nix.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  rofiKeys = config.home-manager.users.${config.galaxy.host.user}.programs.rofi.extraConfig;
in
{
  options.galaxy.programs.rofi-pass.enable = lib.mkEnableOption "rofi-pass and the pass store";

  config = lib.mkIf config.galaxy.programs.rofi-pass.enable {
    environment.variables = {
      PASSWORD_STORE_DIR = "$HOME/.password-store";
      ROFI_PASS_CLIPBOARD_BACKEND = "xclip";
      ROFI_PASS_BACKEND = "xdotool";
    };

    environment.systemPackages = [
      (config.galaxy.lib.mkScript pkgs {
        name = "rofi-pass";
        src = ./rofi-pass;
        excludeShellChecks = [
          "SC1090"
          "SC2034"
        ];
        runtimeInputs = with pkgs; [
          rofi
          pass
          xclip
          xdotool
          libnotify
        ];
      })
    ];

    home-manager.users.${config.galaxy.host.user} = {
      home.packages = with pkgs; [
        pass
        pinentry-curses
        pwgen
      ];

      xdg.configFile."rofi-pass/config".text = ''
        root=$HOME/.password-store
        ${import ./config.nix { inherit lib pkgs rofiKeys; }}
      '';
    };
  };
}
