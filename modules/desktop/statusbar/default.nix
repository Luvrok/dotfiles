# dwmblocks and the db-* blocks it runs (names are hardcoded in the dwmblocks config),
# plus dwm-volume/dwm-brightness, which dwm keys call and which refresh the bar.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  mkScript = config.galaxy.lib.mkScript pkgs;

  scripts = {
    db-date = [ pkgs.coreutils ];
    db-memory = with pkgs; [
      procps
      gawk
      gnused
    ];
    db-rec = [ pkgs.coreutils ];
    db-volume = with pkgs; [
      wireplumber
      gawk
      gnugrep
    ];
    db-wifi = with pkgs; [
      iwd
      iw
      iproute2
      gawk
      gnugrep
    ];
    db-xkb = with pkgs; [
      xset
      xkb-switch
      gawk
      gnugrep
    ];
    dwm-volume = with pkgs; [
      wireplumber
      libnotify
      procps
      gawk
      gnugrep
    ];
    dwm-brightness = with pkgs; [
      ddcutil
      libnotify
      gawk
    ];
  }
  // lib.optionalAttrs config.galaxy.host.isLaptop {
    db-battery = [ pkgs.coreutils ];
  };
in
{
  options.galaxy.desktop.statusbar.enable = lib.mkEnableOption "dwmblocks with the db-* scripts";

  config = lib.mkIf config.galaxy.desktop.statusbar.enable {
    environment.systemPackages = lib.mapAttrsToList (
      name: runtimeInputs:
      mkScript {
        inherit name runtimeInputs;
        src = ./scripts/${name};
        excludeShellChecks = lib.optional (name == "db-memory") "SC2005";
      }
    ) scripts;

    services.xserver.displayManager.sessionCommands = lib.mkAfter ''
      dwmblocks &
    '';
  };
}
