{ pkgs, ... }:

let
  # hyprland's quickshell asks while it runs (hypr-pinentry, from
  # modules/nixos/hyprland), the terminal otherwise. a full path, gpg-agent's
  # PATH may not have it
  pinentry = pkgs.writeShellScriptBin "pinentry" ''
    hypr=/run/current-system/sw/bin/hypr-pinentry
    if [ -x "$hypr" ] && "$hypr" --check; then
      exec "$hypr" "$@"
    fi
    exec ${pkgs.pinentry-curses}/bin/pinentry-curses "$@"
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
