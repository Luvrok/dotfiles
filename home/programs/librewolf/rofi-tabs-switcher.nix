{ lib, stdenv, fetchFromGitHub, runCommand, writeText, makeWrapper
, rofi, python3, zip, theme ? null }:

let
  version = "1.1";

  # --- source ---
  # Вариант A: локальная папка (как было)
  # src = ./rofi-tabs-switcher;
  #
  # Вариант B: с GitHub. Заполни owner/repo/rev, hash оставь lib.fakeHash,
  # запусти `nix build` — Nix выдаст правильный hash в ошибке, подставь его.
  src = fetchFromGitHub {
    owner = "Luvrok";              # TODO
    repo  = "rofi-tab-switcher";   # TODO
    rev   = "f9679dc82a52a18c3b65349ef991244998aaa781";                    # TODO: пин конкретного коммита, не master
    hash  = "sha256-XNa6aUR0olMvUHwDqyVFdfjZcAW1yYbD95UX0pMOyvI=";          # TODO: заменить на реальный
  };

  # --- native messaging helper (backend) ---
  native_helper = stdenv.mkDerivation {
    pname = "rofi-tab-switcher-helper";
    inherit version src;

    # python3 нужен, чтобы patchShebangs разрешил `#!/usr/bin/env python3`
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

  # --- WebExtension .xpi (просто zip нужных файлов) ---
  xpi = stdenv.mkDerivation {
    pname = "rofi-tab-switcher-xpi";
    inherit version src;

    nativeBuildInputs = [ zip ];
    dontConfigure = true;

    buildPhase = ''
      runHook preBuild
      mkdir ext
      # кладём только файлы расширения, без .py/.nix/.sh
      cp manifest.json background.js ext/
      [ -d icons ] && cp -r icons ext/
      # детерминированный архив: фиксируем mtime (1980-01-01, минимум для zip)
      find ext -exec touch -d @315532800 {} +
      ( cd ext && zip -q -X -r -9 ../rofi-tab-switcher.xpi . )
      runHook postBuild
    '';

    installPhase = ''
      install -Dm644 rofi-tab-switcher.xpi $out/rofi-tab-switcher.xpi
    '';
  };

  # --- native messaging manifest ---
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
