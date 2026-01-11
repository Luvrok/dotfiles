{ config, lib, pkgs, inputs, ... }:

let
  dwm = pkgs.fetchFromGitHub {
    owner = "Luvrok";
    repo = "dwm";
    rev = "9eaf0b930afe8e19af25df8ef26fbf7d76fbe0e0";
    hash = "sha256-BJQu5+L9p+A8lgUH3oOy1Iq8zAhIg7u/Bo4FRUkMjaU=";
  };
  st = pkgs.fetchFromGitHub {
    owner = "Luvrok";
    repo = "st";
    rev = "137e80e557b15b475f3a0014637df47bcdcbf71d";
    hash = "sha256-a8xrU/JDREtLi+e2OSL4Z0+0MqjQ9WnPmnQO4YUvcFQ=";
  };
in
{
  imports = [
    ./extraShell.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      dwm = prev.dwm.overrideAttrs (old: {
        pname = "dwm";
        version = "9eaf0b930afe8e19af25df8ef26fbf7d76fbe0e0";
        src = dwm;
      });
    })
    (self: super: {
      ranger = super.ranger.overrideAttrs (
        final: prev: {
          postPatch = ''
                    substituteInPlace ranger/data/scope.sh \
          --replace "# video/*)" "video/*)" \
          --replace "#     # Get frame 10% into video" "    # Get frame 10% into video" \
          --replace "#     ffmpegthumbnailer -i \"\''${FILE_PATH}\" -o \"\''${IMAGE_CACHE_PATH}\" -s 0 && exit 6" \
              '    ffmpegthumbnailer -i "''${FILE_PATH}" -o "''${IMAGE_CACHE_PATH}" -s 0 && exit 6
                    exit 1;;'
          '';
        }
      );
    })
    (final: prev: {
      st = prev.st.overrideAttrs (old: {
        pname = "st";
        version = "137e80e557b15b475f3a0014637df47bcdcbf71d";
        src = st;
      });
    })
    (import ./mpv-config.nix)
    inputs.nur.overlays.default
  ];
}
