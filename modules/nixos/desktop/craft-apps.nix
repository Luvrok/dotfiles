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
    version = "0.23.1";
    hash = "sha256-BXR7PlJ+HgoMHeOZcDYc84yPyn6NPjYB7yCC+w5t0X8=";
  };

  vectorcraft = craftApp {
    pname = "vectorcraft";
    version = "0.24.1";
    hash = "sha256-vc5+gumB+fTtC/JfpvJeb+T6sn6JZB5vlIiZ4BsTpRQ=";
  };

  wordcraft = craftApp {
    pname = "wordcraft";
    version = "0.18.1";
    hash = "sha256-u8XBWwbUQDz9WllHW9+SZKScK88fktEjMRtQqdzjyIg=";
  };

  gridcraft = craftApp {
    pname = "gridcraft";
    version = "0.19.1";
    hash = "sha256-WxzhCtbHotOJJJ39JZAQAUqF/OGqQsYn/EzaVxZx4iE=";
  };

  pdfcraft = craftApp {
    pname = "pdfcraft";
    version = "0.21.1";
    hash = "sha256-cwJ2zamt2z1I8mxgJobRj8W8Dr42CmCi9SLXDP1CjSE=";
  };

  deckcraft = craftApp {
    pname = "deckcraft";
    version = "0.18.1";
    hash = "sha256-aN+fBA0/bEzkqQSq3sYzlh+hmSSPChqjZvpkWXrgmGc=";
  };

  soundcraft = craftApp {
    pname = "soundcraft";
    version = "0.20.1";
    hash = "sha256-TbtAKkE+wqUxA7n6d9Y1bm/usIbZSXXJXmNcdLQ02vg=";
  };

  effectcraft = craftApp {
    pname = "effectcraft";
    version = "0.24.1";
    hash = "sha256-n4oWz3QUfJ4qw7ZfpvW+lqPhDq2S3fCNVE9dOZCtZNw=";
  };

  figcraft = craftApp {
    pname = "figcraft";
    version = "0.18.1";
    hash = "sha256-lYaULdYxuWtMVSKYjp6AITkHuAIv+vvKYko/wRrnqek=";
  };

  filmcraft = craftApp {
    pname = "filmcraft";
    version = "0.20.1";
    hash = "sha256-SiWuyy6UgbZec1NSi8qeSoxTiN1V8Uhv/mRQLgi9+gI=";
  };
}
