{ config, lib, pkgs, inputs, ... }:

{
  imports = [
    ./extraShell.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      dwm = prev.dwm.overrideAttrs (old: {
        version = "dwm-6.7";
        src = inputs.dwm.outPath;
        buildInputs = (old.buildInputs or []) ++ (with pkgs.xorg; [
          libXcursor
        ]);
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
