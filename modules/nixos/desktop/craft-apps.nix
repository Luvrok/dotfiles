# the StoryTold apps as the upstream prebuilt AppImages. building them from
# source means compiling a rust workspace and its test suite on every update;
# the releases already ship a wrapped binary, so nix only extracts and wraps it
{ pkgs }:

let
  inherit (pkgs) appimageTools fetchurl;

  craftApp =
    {
      pname,
      version,
      hash,
    }:
    let
      src = fetchurl {
        url = "https://github.com/storytold/${pname}/releases/download/v${version}/${pname}-${version}-linux-x86_64.AppImage";
        inherit hash;
      };
      contents = appimageTools.extract {
        inherit pname version src;
      };
      desktop = "ai.storyteller.${pname}.desktop";
    in
    appimageTools.wrapType2 {
      inherit pname version src;

      # egui/wgpu apps: the renderer, wayland/x11 and the clipboard come from
      # the system, not from the appimage
      extraPkgs =
        p: with p; [
          dbus
          libx11
          libxcb
          libxcursor
          libxi
          libxkbcommon
          libxrandr
          vulkan-loader
          wayland
        ];

      extraInstallCommands = ''
        install -Dm444 ${contents}/${desktop} $out/share/applications/${desktop}
        if [ -d ${contents}/usr/share/icons ]; then
          mkdir -p $out/share
          cp -r ${contents}/usr/share/icons $out/share/icons
        fi
      '';
    };
in
{
  photocraft = craftApp {
    pname = "photocraft";
    version = "0.22.0";
    hash = "sha256-zuk05sOMD/f4zX7gNpQSi+Bb4Tf8QwEYDi9xbn0qH58=";
  };

  vectorcraft = craftApp {
    pname = "vectorcraft";
    version = "0.23.0";
    hash = "sha256-ihMPRI+o3/CiedzvylYin1cCyzQRIyY0NtWHxFviqOQ=";
  };

  wordcraft = craftApp {
    pname = "wordcraft";
    version = "0.17.0";
    hash = "sha256-YGs64zDHZ8+hkoA9uo63udKcZs3ynQyr3gg/F/Bq0Ws=";
  };

  gridcraft = craftApp {
    pname = "gridcraft";
    version = "0.18.0";
    hash = "sha256-/eL5mCrHaQJlIctvcQ7Ja02RmxY0rWixWyub9iRnAgw=";
  };

  pdfcraft = craftApp {
    pname = "pdfcraft";
    version = "0.20.0";
    hash = "sha256-An5iKZuCNTYANz5sp0xEEhPvVAbnDSf38a734Fp4h40=";
  };

  deckcraft = craftApp {
    pname = "deckcraft";
    version = "0.17.0";
    hash = "sha256-oD0vCRpUHDKxT09n3olynShpjcKT8fmmIvVBnWQ9pZc=";
  };
}
