{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./extraShell.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      dwm = prev.dwm.overrideAttrs (_: {
        version = "dwm-6.7";
        src = inputs.dwm.outPath;
      });
    })
    (final: prev: {
      st = prev.st.overrideAttrs (_: {
        version = "st-0.9.3";
        src = inputs.st.outPath;
      });
    })
    (import ./mpv-config.nix)
    inputs.nur.overlays.default
  ];
}
