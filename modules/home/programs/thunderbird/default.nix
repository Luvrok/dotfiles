{ pkgs, ... }:

let
  cfg = import ./settings.nix { inherit pkgs; };
in
{
  programs.thunderbird = {
    enable = true;

    # esr, not the rolling package: the mail client should not move on every
    # nixpkgs bump
    package = pkgs.thunderbird-esr;

    # All of these are in the thunderbird policy table for the esr releases:
    # telemetry, the system add-on updater and self updates do nothing on a
    # store that nix owns
    policies = {
      DisableTelemetry = true;
      DisableSystemAddonUpdate = true;
      AppAutoUpdate = false;
      RequestedLocales = "en-US";
    };

    profiles.life = {
      isDefault = true;
      inherit (cfg) settings;
    };
  };
}
