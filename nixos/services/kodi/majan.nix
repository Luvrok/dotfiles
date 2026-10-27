# majan, of KarmaMole's skins (github.com/KarmaMole/kodi-skins): settings
# -> interface -> skin, ./defaults.py picks it the first time. it needs
# skin variables, kodi's repository has it, nixpkgs doesn't. jurialmunkey
# and infotagger are ./addons.nix's, tmdb helper's too
{
  inputs,
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
in
buildKodiAddon {
  pname = "skin.majan";
  namespace = "skin.majan";
  version = inputs.kodi-skins.shortRev;
  src = "${inputs.kodi-skins}/skins/skin.majan";
  propagatedBuildInputs = [ skinvariables ];
  # _src has the generators of its fonts, textures and xml. its grotesk
  # and display fonts have no cyrillic: a third font in kodi's settings ->
  # interface -> skin -> fonts, "JetBrains Mono" (nl, the quickshell font),
  # majan's with jetbrains in place of both. its black curtain over kodi
  # while a video plays waits for a frame of kodi's own player, mpv plays
  # in its own window: off. a line they replace that's gone after an update
  # fails the build
  postInstall = ''
    cd $out/share/kodi/addons/skin.majan
    chmod -R u+w .
    rm -rf _src
    cp ${jetbrains}-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf fonts/
    sed -n '/<fontset id="Default"/,/<\/fontset>/p' 1080i/Font.xml | sed \
      -e 's#<fontset id="Default" idloc="31900">#<fontset id="JetBrains Mono" unicode="true">#' \
      -e 's#HankenGrotesk-#JetBrainsMonoNLNerdFont-#g' \
      -e 's#MajanDisplay-ExtraBold#JetBrainsMonoNLNerdFont-ExtraBold#g' > jetbrains.xml
    grep -q '<fontset id="JetBrains Mono"' jetbrains.xml
    sed -i -e '/<\/fonts>/{r jetbrains.xml' -e 'd}' 1080i/Font.xml
    echo '</fonts>' >> 1080i/Font.xml
    rm jetbrains.xml
    substituteInPlace 1080i/Custom_1153_PlayCurtain.xml --replace-fail \
      '<visible>[Player.HasVideo | [Player.HasMedia + !Player.HasAudio]] + !Window.IsActive(fullscreenvideo) + String.IsEmpty(Window(Home).Property(majan.fsseen)) + !System.IdleTime(8)</visible>' \
      '<visible>false</visible>'
    # the number before a page's name is the key that opens it
    # (./keyboard.xml): 04 tv (majan's 10), 05 tmdb helper (02, the videos
    # window's), / search (05). 06, the downloads, is ./moviepipe's
    substituteInPlace 1080i/Includes_Misc.xml --replace-fail \
      '<param name="index" value="10"/>' '<param name="index" value="04"/>'
    substituteInPlace 1080i/Includes_Views_Video.xml --replace-fail \
      '<variable name="VidView_Index">' \
      '<variable name="VidView_Index"><value condition="String.StartsWith(Container.FolderPath,plugin://plugin.video.themoviedb.helper/)">05</value>'
    substituteInPlace 1080i/Custom_1150_Search.xml --replace-fail \
      '<param name="index" value="05"/>' '<param name="index" value="/"/>'
    # its rows of posters run to the screen's edge, 1920: with the skin
    # zoomed out (settings -> interface -> skin -> zoom) they stop short of
    # it, past the page's right margin. they end at the margin, 1824. the
    # home row's focused poster (lifted, zoomed) went 3 px under the
    # screen's bottom with no zoom: 6 px up
    substituteInPlace 1080i/Includes_Home.xml \
      --replace-fail '<width>1836</width>' '<width>1740</width>' \
      --replace-fail '<constant name="home_hub_list_w">1608</constant>' \
      '<constant name="home_hub_list_w">1512</constant>' \
      --replace-fail '<constant name="home_newest_list_y">44</constant>' \
      '<constant name="home_newest_list_y">38</constant>'
    substituteInPlace 1080i/Includes_Search.xml --replace-fail \
      '<width>1836</width>' '<width>1740</width>'
  '';
}
