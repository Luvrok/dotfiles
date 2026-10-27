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
  nerd-fonts,
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

  jetbrains = "${nerd-fonts.jetbrains-mono}/share/fonts/truetype/NerdFonts/JetBrainsMono/JetBrainsMonoNLNerdFont";

  # changes to a skin, in its folder. a line they replace that's gone
  # after an update fails the build
  fixes = {
    # its grotesk and display fonts have no cyrillic: jetbrains mono nl,
    # the quickshell font, in their files, the same weights. its black
    # curtain over kodi while a video plays waits for a frame of kodi's own
    # player, mpv plays in its own window: off
    "skin.majan" = ''
      for w in Regular Medium SemiBold Bold ExtraBold; do
        cp ${jetbrains}-$w.ttf fonts/HankenGrotesk-$w.ttf
      done
      cp ${jetbrains}-ExtraBold.ttf fonts/MajanDisplay-ExtraBold.ttf
      substituteInPlace 1080i/Custom_1153_PlayCurtain.xml --replace-fail \
        '<visible>[Player.HasVideo | [Player.HasMedia + !Player.HasAudio]] + !Window.IsActive(fullscreenvideo) + String.IsEmpty(Window(Home).Property(majan.fsseen)) + !System.IdleTime(8)</visible>' \
        '<visible>false</visible>'
    '';
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
        cd $out/share/kodi/addons/${id}
        chmod -R u+w .
        rm -rf _src
        ${fixes.${id} or ""}
      '';
    };
in
map skin (lib.attrNames (builtins.readDir "${inputs.kodi-skins}/skins"))
