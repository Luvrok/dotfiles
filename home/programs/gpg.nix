{ config, lib, pkgs, ...}:

let
  pinentryRofiThemed = pkgs.symlinkJoin {
    name = "pinentry-rofi-themed";
    buildInputs = [ pkgs.makeWrapper ];
    paths = [ pkgs.pinentry-rofi ];
    postBuild = ''
      wrapProgram $out/bin/pinentry-rofi \
        --add-flags "-- -theme ${config.home.homeDirectory}/.config/rofi/keyring.rasi"
        ln -sf $out/bin/pinentry-rofi $out/bin/pinentry
    '';
  };
in
{
  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 60;
    pinentry.package = pinentryRofiThemed;
  };
}
