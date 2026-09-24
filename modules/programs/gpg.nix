{
  config,
  lib,
  pkgs,
  ...
}:

let
  pinentryRofiThemed = pkgs.symlinkJoin {
    name = "pinentry-rofi-themed";
    buildInputs = [ pkgs.makeWrapper ];
    paths = [ pkgs.pinentry-rofi ];
    postBuild = ''
      wrapProgram $out/bin/pinentry-rofi \
        --add-flags "-- -theme /home/${config.galaxy.host.user}/.config/rofi/keyring.rasi"
        ln -sf $out/bin/pinentry-rofi $out/bin/pinentry
    '';
  };
in
{
  options.galaxy.programs.gpg.enable = lib.mkEnableOption "gpg with a rofi pinentry";

  config = lib.mkIf config.galaxy.programs.gpg.enable {
    home-manager.users.${config.galaxy.host.user} = {
      programs.gpg.enable = true;

      services.gpg-agent = {
        enable = true;
        defaultCacheTtl = 60;
        pinentry.package = pinentryRofiThemed;
      };
    };
  };
}
