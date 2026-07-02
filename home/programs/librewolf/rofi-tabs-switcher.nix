{ lib, stdenv, fetchFromGitHub, runCommand, writeText, makeWrapper
, rofi, python3, zip, theme ? null }:

let
  version = "1.1";

  src = fetchFromGitHub {
    owner = "Luvrok";
    repo  = "rofi-tab-switcher";
    rev   = "f9679dc82a52a18c3b65349ef991244998aaa781";
    hash  = "sha256-XNa6aUR0olMvUHwDqyVFdfjZcAW1yYbD95UX0pMOyvI=";
  };

  native_helper = stdenv.mkDerivation {
    pname = "rofi-tab-switcher-helper";
    inherit version src;

    buildInputs = [ python3 ];
    nativeBuildInputs = [ makeWrapper ];
    dontBuild = true;

    installPhase = ''
      install -Dm755 rofiface.py $out/libexec/rofiface.py
      patchShebangs $out/libexec/rofiface.py
      makeWrapper $out/libexec/rofiface.py $out/bin/rofiface \
        --prefix PATH : ${lib.makeBinPath [ rofi ]} \
        ${lib.optionalString (theme != null)
          ''--set ROFI_TAB_SWITCHER_THEME "${theme}"''}
    '';
  };

  xpi = stdenv.mkDerivation {
    pname = "rofi-tab-switcher-xpi";
    inherit version src;

    nativeBuildInputs = [ zip ];
    dontConfigure = true;

    buildPhase = ''
      runHook preBuild
      mkdir ext
      cp manifest.json background.js ext/
      [ -d icons ] && cp -r icons ext/
      find ext -exec touch -d @315532800 {} +
      ( cd ext && zip -q -X -r -9 ../rofi-tab-switcher.xpi . )
      runHook postBuild
    '';

    installPhase = ''
      install -Dm644 rofi-tab-switcher.xpi $out/rofi-tab-switcher.xpi
    '';
  };

  manifest = {
    name = "rofi_interface";
    description = "Native backend for rofi tab switcher.";
    type = "stdio";
    allowed_extensions = [ "@rofi.tab.switcher" ];
    path = "${native_helper}/bin/rofiface";
  };

  plugin = runCommand "rofi-tab-switcher-plugin" { } ''
    install -DT ${writeText "rofi_interface.json" (builtins.toJSON manifest)} \
      $out/lib/mozilla/native-messaging-hosts/rofi_interface.json
  '';
in
  { inherit native_helper plugin xpi; }
