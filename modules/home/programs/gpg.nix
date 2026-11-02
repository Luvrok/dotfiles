{ config, pkgs, ... }:

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

  # hyprland's quickshell asks while it runs (hypr-pinentry, from
  # nixos/services/hyprland), rofi otherwise. a full path, gpg-agent's PATH
  # may not have it
  pinentry = pkgs.writeShellScriptBin "pinentry" ''
    hypr=/run/current-system/sw/bin/hypr-pinentry
    if [ -x "$hypr" ] && "$hypr" --check; then
      exec "$hypr" "$@"
    fi
    exec ${pinentryRofiThemed}/bin/pinentry-rofi "$@"
  '';
in
{
  programs.gpg.enable = true;

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 60;
    pinentry.package = pinentry;
  };
}
