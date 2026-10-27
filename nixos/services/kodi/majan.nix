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
  # majan's with jetbrains in place of both, 12% smaller: a monospace is
  # wider (majan's mono and number fonts stay). its black curtain over kodi while a video plays waits for a
  # frame of kodi's own player, mpv plays in its own window: off. a line
  # they replace that's gone after an update fails the build
  postInstall = ''
    cd $out/share/kodi/addons/skin.majan
    chmod -R u+w .
    rm -rf _src
    cp ${jetbrains}-{Regular,Medium,SemiBold,Bold,ExtraBold}.ttf fonts/
    sed -n '/<fontset id="Default"/,/<\/fontset>/p' 1080i/Font.xml | sed \
      -e 's#<fontset id="Default" idloc="31900">#<fontset id="JetBrains Mono" unicode="true">#' \
      -e 's#HankenGrotesk-#JetBrainsMonoNLNerdFont-#g' \
      -e 's#MajanDisplay-ExtraBold#JetBrainsMonoNLNerdFont-ExtraBold#g' |
      awk '{
        if (/JetBrainsMonoNLNerdFont-/ && match($0, /<size>[0-9]+<\/size>/)) {
          n = substr($0, RSTART + 6, RLENGTH - 13)
          $0 = substr($0, 1, RSTART - 1) "<size>" int(n * 0.88 + 0.5) "</size>" substr($0, RSTART + RLENGTH)
        }
        print
      }' > jetbrains.xml
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
    # it, past the page's right margin. they end at the margin, 1824
    substituteInPlace 1080i/Includes_Home.xml \
      --replace-fail '<width>1836</width>' '<width>1740</width>' \
      --replace-fail '<constant name="home_hub_list_w">1608</constant>' \
      '<constant name="home_hub_list_w">1512</constant>'
    substituteInPlace 1080i/Includes_Search.xml --replace-fail \
      '<width>1836</width>' '<width>1740</width>'
    # home: the spotlight 40 px up, nearer the bar, its column ending 20 px
    # over the newest row's rule (a 3-line title pushed the play button's
    # frame onto it), the rule 44 px up (760 -> 716). the row's posters 36
    # px up (826 -> 790): the focused one's frame, lifted and zoomed, went
    # under the screen's bottom, now 30 px over it
    substituteInPlace 1080i/Includes_Home.xml \
      --replace-fail '<visible>Integer.IsGreater(Container(9101).NumItems,0)</visible>' \
      '<top>-40</top><visible>Integer.IsGreater(Container(9101).NumItems,0)</visible>' \
      --replace-fail '<height>592</height>' '<height>568</height>' \
      --replace-fail '<constant name="home_newest_list_y">44</constant>' \
      '<constant name="home_newest_list_y">52</constant>'
    # its top bar: the menu, page names, clock and icons 16 px down, the
    # rule under them stays (the pages below it don't move). the active
    # tab's underline 20 px over the rule, was 32
    substituteInPlace 1080i/Constants.xml \
      --replace-fail '<constant name="home_row_y">760</constant>' '<constant name="home_row_y">716</constant>' \
      --replace-fail '<constant name="topbar_item_top">36</constant>' '<constant name="topbar_item_top">52</constant>' \
      --replace-fail '<constant name="topbar_icon_top">47</constant>' '<constant name="topbar_icon_top">63</constant>'
    # the film page with tmdb helper and movie pipe: the cast, "похожие",
    # "режиссёр" (./majan-moviepipe.xml)
    cp ${./majan-moviepipe.xml} 1080i/Includes_MoviePipe.xml
    substituteInPlace 1080i/Includes.xml --replace-fail \
      '<include file="Includes_CustomRows.xml"/>' \
      '<include file="Includes_CustomRows.xml"/><include file="Includes_MoviePipe.xml"/>'
    substituteInPlace 1080i/Includes_VideoInfo.xml \
      --replace-fail '<onback>9010</onback>' '<onback>9010</onback><include>MoviePipe_MoreButtons</include>' \
      --replace-fail '<description>16px left / 14px top inner padding so the 5% zoom + focus frame are not clipped</description>' \
      '<include>MoviePipe_CastList</include>'
  '';
}
