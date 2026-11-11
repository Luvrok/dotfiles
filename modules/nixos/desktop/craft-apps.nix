# the StoryTold apps as the upstream prebuilt AppImages. building them from
# source means compiling a rust workspace and its test suite on every update;
# the releases already ship a wrapped binary, so nix only extracts and wraps it
# bump the versions and hashes with `nix run .#update-craft-apps`
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

      # the app lives on after the menu's helper exits: bwrap's default
      # --die-with-parent would take it down with that helper
      dieWithParent = false;

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
        # the appimage also ships a <app>-cli, the mcp and automation entry
        # point. nix only wraps the gui binary, so expose the cli as well
        if [ -x ${contents}/usr/bin/${pname}-cli ]; then
          cat > $out/bin/${pname}-cli <<WRAPPER
#!${pkgs.runtimeShell}
exec ${contents}/usr/bin/${pname}-cli "\$@"
WRAPPER
          chmod +x $out/bin/${pname}-cli
        fi

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

  soundcraft = craftApp {
    pname = "soundcraft";
    version = "0.19.0";
    hash = "sha256-qt7XTk8TLAM6zBIjx3anTlmnUdyQiEG0wxVy44k5GY8=";
  };

  effectcraft = craftApp {
    pname = "effectcraft";
    version = "0.23.1";
    hash = "sha256-eQVIXX6RmZoMGey6RH0N/RHBO92xMr35zKZc2LYGcfs=";
  };

  figcraft = craftApp {
    pname = "figcraft";
    version = "0.17.0";
    hash = "sha256-p0nZ+AdMvS3H0EoW1HJiABolKDkfoVO9bFxOT4TI5BQ=";
  };

  filmcraft = craftApp {
    pname = "filmcraft";
    version = "0.19.0";
    hash = "sha256-LwnP9pY7VbwhYBWAYK+N4iaw7I/CI6GYsQFFpY4jj+g=";
  };
}
