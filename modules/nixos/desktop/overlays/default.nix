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
          rev = "a2a1d02048955c5367348cdedf355cbac977e6c1";
          hash = "sha256-9lB7FnOIHqBR9woBidxQg/wLjJYuNuE+HLLeWIICHOQ=";
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
