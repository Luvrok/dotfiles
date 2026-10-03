{ pkgs, lib, ... }:

let
  # -a: проигрывать анимации, -s f: вписывать в окно (мелкие картинки тоже растягиваются)
  nsxiv = pkgs.symlinkJoin {
    name = "nsxiv-wrapped";
    paths = [ pkgs.nsxiv pkgs.nsxiv.man ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/nsxiv --add-flags "-a -s f"
    '';
  };

  imageTypes = [
    "image/png"
    "image/jpeg"
    "image/gif"
    "image/webp"
    "image/bmp"
    "image/tiff"
    "image/svg+xml"
    "image/avif"
    "image/heif"
    "image/heic"
    "image/jxl"
  ];
in
{
  home.packages = [ nsxiv ];

  xdg.mimeApps = {
    enable = true;
    defaultApplications = lib.genAttrs imageTypes (_: "nsxiv.desktop");
  };
}
