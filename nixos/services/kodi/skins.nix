# KarmaMole's skins (github.com/KarmaMole/kodi-skins), every one in its
# skins/, picked in kodi: settings -> interface -> skin. each needs skin
# variables, kodi's repository has it, nixpkgs doesn't. the optional
# helpers (tmdb helper, embuary) install from inside kodi
{
  inputs,
  lib,
  buildKodiAddon,
  jurialmunkey,
  infotagger,
}:

let
  skinvariables = buildKodiAddon {
    pname = "skinvariables";
    namespace = "script.skinvariables";
    version = inputs.kodi-skinvariables.shortRev;
    src = inputs.kodi-skinvariables;
    propagatedBuildInputs = [
      jurialmunkey
      infotagger
    ];
  };

  skin =
    id:
    buildKodiAddon {
      pname = id;
      namespace = id;
      version = inputs.kodi-skins.shortRev;
      src = "${inputs.kodi-skins}/skins/${id}";
      propagatedBuildInputs = [ skinvariables ];
      # _src has the generators of its fonts, textures and xml
      postInstall = ''
        rm -rf $out/share/kodi/addons/${id}/_src
      '';
    };
in
map skin (lib.attrNames (builtins.readDir "${inputs.kodi-skins}/skins"))
