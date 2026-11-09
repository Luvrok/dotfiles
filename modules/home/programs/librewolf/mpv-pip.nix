{
  lib,
  stdenv,
  runCommand,
  writeText,
  makeWrapper,
  python3,
  zip,
  mpv,
  yt-dlp,
}:

let
  src = ./mpv-pip;

  xpi = runCommand "mpv-pip-xpi" { nativeBuildInputs = [ zip ]; } ''
    mkdir ext
    cp ${src}/manifest.json ${src}/background.js ext/
    find ext -exec touch -d @315532800 {} +
    mkdir -p $out
    (cd ext && zip -q -X -r -9 $out/mpv-pip.xpi .)
  '';

  # the browser starts this, so mpv and yt-dlp have to be on its PATH
  host = stdenv.mkDerivation {
    pname = "mpv-pip-host";
    version = "1.0";
    nativeBuildInputs = [ makeWrapper ];
    dontUnpack = true;
    dontBuild = true;

    installPhase = ''
      install -Dm755 ${./mpv-pip-host}/mpv-pip.py $out/libexec/mpv-pip.py
      patchShebangs $out/libexec/mpv-pip.py
      makeWrapper $out/libexec/mpv-pip.py $out/bin/mpv-pip-host \
        --prefix PATH : ${
          lib.makeBinPath [
            python3
            mpv
            yt-dlp
          ]
        }
    '';
  };

  manifest = {
    name = "mpv_pip";
    description = "Open the current tab in an mpv picture-in-picture window.";
    type = "stdio";
    allowed_extensions = [ "@mpv.pip" ];
    path = "${host}/bin/mpv-pip-host";
  };

  plugin = runCommand "mpv-pip-plugin" { } ''
    install -DT ${writeText "mpv_pip.json" (builtins.toJSON manifest)} \
      $out/lib/mozilla/native-messaging-hosts/mpv_pip.json
  '';
in
{
  inherit xpi plugin;
}
