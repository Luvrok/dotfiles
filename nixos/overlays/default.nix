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
    (final: prev: {
      dwm = prev.dwm.overrideAttrs (old: {
        version = "dwm-6.7";
        src = inputs.dwm.outPath;
        buildInputs =
          (old.buildInputs or [ ])
          ++ (with pkgs; [
            libXcursor
            libXres
            yajl
          ]);
      });
    })
    (final: prev: {
      st = prev.st.overrideAttrs (_: {
        version = "st-0.9.3";
        src = inputs.st.outPath;
        buildInputs = with pkgs; [
          libX11
          libXft
          imlib2
        ];
      });
    })
    (final: prev: {
      slock = prev.slock.overrideAttrs (_: {
        version = "slock-1.6";
        src = inputs.slock.outPath;
        buildInputs = with pkgs; [
          libX11
          libxrandr
          libxcrypt
          libxext
          libXinerama
          imlib2
          libXft
        ];
      });
    })
    (final: prev: {
      dwmblocks = prev.dwmblocks.overrideAttrs (old: {
        src = inputs.dwmblocks.outPath;
        buildInputs = with pkgs; [
          libX11
          libxcb
          xcbutil
          pkg-config
        ];
        makeFlags = [ "PREFIX=$(out)" ];
        postPatch = ''
          if grep -q 'void termhandler()' src/main.c; then
            substituteInPlace src/main.c \
              --replace-fail 'void termhandler()' 'void termhandler(int signum)'
          fi
        '';
      });
    })
    (self: super: {
      mpv-config = super.stdenvNoCC.mkDerivation {
        pname = "mpv-config";
        version = "fork-pinned-11.09.2025";
        src = super.fetchFromGitHub {
          owner = "Luvrok";
          repo = "mpv-config";
          rev = "c2a8fed053b01b81df02b2679dbadcf75a7822d4";
          hash = "sha256-jmeOUKAs3gcEuiXqo6FclTGOMrWMcEQdGZlXFpdJjHs=";
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
    (final: prev: {
      llama-cpp =
        (prev.llama-cpp.override {
          rocmSupport = true;
          vulkanSupport = true;
          # Enable BLAS for optimized CPU layer performance (OpenBLAS)
          blasSupport = true;
        }).overrideAttrs
          (oldAttrs: {
            # Enable native CPU optimizations (AVX, AVX2, etc.)
            cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [ "-DGGML_NATIVE=ON" ];
            # Disable Nix's march=native stripping
            preConfigure = ''
              export NIX_ENFORCE_NO_NATIVE=0
              ${oldAttrs.preConfigure or ""}
            '';
          });
    })
    (final: prev: {
      i3 = prev.i3.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace src/render.c --replace-fail 'return deco_height;' 'return 0;'
        '';
        doCheck = false;
      });
    })
    inputs.better-swallow.overlay
    inputs.lazygit.overlays.default
  ];
}
