# majan, of KarmaMole's skins (github.com/KarmaMole/kodi-skins): settings
# -> interface -> skin, ./userdata.nix picks it the first time. it needs
# skin variables, kodi's repository has it, nixpkgs doesn't. jurialmunkey
# and infotagger are ./addons.nix's, tmdb helper's too. what it changes in
# majan's xml and fonts is ./majan-patches.nix, ./majan-patch.py applies it
{
  inputs,
  buildKodiAddon,
  jurialmunkey,
  infotagger,
  nerd-fonts,
  python3,
  writeText,
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

  fonts = "${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono";
  patches = writeText "majan-patches.json" (builtins.toJSON (import ./majan-patches.nix));
in
buildKodiAddon {
  pname = "skin.majan";
  namespace = "skin.majan";
  version = inputs.kodi-skins.shortRev;
  src = "${inputs.kodi-skins}/skins/skin.majan";
  propagatedBuildInputs = [ skinvariables ];
  # _src has the generators of its fonts, textures and xml, kodi doesn't use
  # it. the rest is ./majan-patches.nix: the third fontset (the grotesk and
  # display fonts have no cyrillic), the page numbers that match
  # ./keyboard.xml, the film page of ./moviepipe and home's spacing
  postInstall = ''
    cd $out/share/kodi/addons/skin.majan
    chmod -R u+w .
    rm -rf _src
    ${python3.interpreter} ${./majan-patch.py} . ${patches} ${fonts}
  '';
}
