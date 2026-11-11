{ pkgs, inputs, ... }:
let
  mpv = ./mpv/mpv.conf;
  input = ./mpv/input.conf;
in
{
  imports = [
    ./extraShell.nix
  ];

  nixpkgs.overlays = [
    (self: super: {
      mpv-config = super.stdenvNoCC.mkDerivation {
        pname = "mpv-config";
        version = "fork-pinned-26.10.2026";
        src = super.fetchFromGitHub {
          owner = "Luvrok";
          repo = "mpv-config";
          rev = "d12bb8e851010e8dedfbc051d1868a16c8c9c1b2";
          hash = "sha256-XCO9Z1Xxwco1EkoAh9p3bC+g1IZi4LHw/vmZqKI22vA=";
        };
        # the fork has no mpv.conf and input.conf, they're ./mpv
        installPhase = ''
          set -euo pipefail

          mkdir -p "$out"
          cp -r "$src/portable_config/"* "$out/"

          install -Dm644 ${mpv} "$out/mpv.conf"
          install -Dm644 ${input} "$out/input.conf"

          substituteInPlace "$out/script-opts/memo.conf" \
            --replace '~~/script-opts/memo-history.log' '~/.local/state/mpv/memo-history.log'
        '';
      };
    })
    inputs.lazygit.overlays.default
  ];
}
