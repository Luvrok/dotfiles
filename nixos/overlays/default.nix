{ config, lib, pkgs, inputs, ... }:
let
  mpv = ./mpv/mpv.conf;
  input = ./mpv/input.conf;
  memo = ./mpv/memo.conf;
in
{
  imports = [
    ./extraShell.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      dwm = prev.dwm.overrideAttrs (old: {
        version = "dwm-6.7";
        src = inputs.dwm.outPath;
        buildInputs = (old.buildInputs or []) ++ (with pkgs; [
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
    (final: prev: {
      dwmblocks = prev.dwmblocks.overrideAttrs {
        src = inputs.dwmblocks.outPath;
        buildInputs = with pkgs; [
          libX11
          libxcb
          xcbutil
          pkg-config
        ];
        makeFlags = ["PREFIX=$(out)"];
      };
    })
    (final: prev: {
      dmenu = prev.dmenu.overrideAttrs {
        src = inputs.dmenu.outPath;
        buildInputs = with pkgs; [
          libX11
          libXinerama
          libXft
          pkg-config
        ];
        makeFlags = ["PREFIX=$(out)"];
      };
    })
    (self: super: {
      mpv-config = super.stdenvNoCC.mkDerivation {
        pname = "mpv-config";
        version = "fork-pinned-11.09.2025";
        src = super.fetchFromGitHub {
          owner = "Luvrok";
          repo  = "mpv-config";
          rev   = "c2a8fed053b01b81df02b2679dbadcf75a7822d4";
          hash  = "sha256-jmeOUKAs3gcEuiXqo6FclTGOMrWMcEQdGZlXFpdJjHs=";
        };
        installPhase = ''
          set -euo pipefail

          mkdir -p "$out"
          cp -r "$src/portable_config/"* "$out/"

          rm -f "$out/mpv.conf"
          install -Dm644 ${mpv} "$out/mpv.conf"

          rm -f "$out/inputs.conf"
          install -Dm644 ${input} "$out/input.conf"

          substituteInPlace "$out/script-opts/memo.conf" \
            --replace '~~/script-opts/memo-history.log' '~/.local/state/mpv/memo-history.log'
        '';
      };
    })
    inputs.nur.overlays.default
  ];
}
