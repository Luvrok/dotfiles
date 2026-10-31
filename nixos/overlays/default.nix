{ pkgs, inputs, ... }:
let
  mpv = ./mpv/mpv.conf;
  input = ./mpv/input.conf;
in
{
  imports = [
    ./extraShell.nix
    # llama.cpp source pin, shared with jedha
    ../../modules/llm/llama-cpp.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      stable-diffusion-cpp = prev.stable-diffusion-cpp.overrideAttrs (_: {
        version = "master-968-8cd731e";
        src = prev.fetchFromGitHub {
          owner = "leejet";
          repo = "stable-diffusion.cpp";
          tag = "master-968-8cd731e";
          hash = "sha256-NZUNtYNSDhAEpm+4Ja/RD/0ynZAGynczBcrjxo234+Y=";
          fetchSubmodules = true;
        };
      });
    })
    (self: super: {
      mpv-config = super.stdenvNoCC.mkDerivation {
        pname = "mpv-config";
        version = "fork-pinned-26.10.2026";
        src = super.fetchFromGitHub {
          owner = "Luvrok";
          repo = "mpv-config";
          rev = "75c1028e6ddaa15f3de46d0ec8bba3c1779e6f17";
          hash = "sha256-oC8jZwgxnpyw8Hq1il1m9ly/H3HFITZjUCZ1cNhwhl8=";
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
    (final: prev: {
      llama-cpp =
        (prev.llama-cpp.override {
          rocmSupport = true;
          # the only backend that works on the nvidia host
          vulkanSupport = true;
          blasSupport = true;
        }).overrideAttrs
          (oldAttrs: {
            cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
              "-DGGML_NATIVE=ON"
              "-DLLAMA_BUILD_TESTS=OFF" # later -D wins
            ];
            preConfigure = ''
              export NIX_ENFORCE_NO_NATIVE=0
              ${oldAttrs.preConfigure or ""}
            '';
            doCheck = false;
          });
    })
    inputs.lazygit.overlays.default
  ];
}
