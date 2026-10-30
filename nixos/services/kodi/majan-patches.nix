# what ../kodi/majan.nix changes in majan's own xml, as data for
# ./majan-patch.py. every patch names the file it's in, the exact text it
# replaces and what with; by default that text must be there once, "all"
# when the skin has it more than once on purpose. a skin update that
# rewrites one of them fails the build with the file and the text, not
# with a silent no-op or with a replacement in the wrong place.
{
  # majan's film page with tmdb helper and movie pipe: the cast, "similar"
  # and the trailer, "more by director" (./majan-moviepipe.xml)
  copy = [
    {
      from = ./majan-moviepipe.xml;
      to = "1080i/Includes_MoviePipe.xml";
    }
  ];

  patch = [
    # its black curtain over kodi while a video plays waits for a frame of
    # kodi's own player, mpv plays in its own window: off
    {
      file = "1080i/Custom_1153_PlayCurtain.xml";
      from = "<visible>[Player.HasVideo | [Player.HasMedia + !Player.HasAudio]] + !Window.IsActive(fullscreenvideo) + String.IsEmpty(Window(Home).Property(majan.fsseen)) + !System.IdleTime(8)</visible>";
      to = "<visible>false</visible>";
    }

    # the number before a page's name is the key that opens it
    # (./keyboard.xml): 04 tv (majan's 10), 05 tmdb helper (02, the videos
    # window's), / search (05). 06, the downloads, is ./moviepipe's
    {
      file = "1080i/Includes_Misc.xml";
      from = ''<param name="index" value="10"/>'';
      to = ''<param name="index" value="04"/>'';
    }
    {
      file = "1080i/Includes_Views_Video.xml";
      from = ''<variable name="VidView_Index">'';
      to = ''<variable name="VidView_Index"><value condition="String.StartsWith(Container.FolderPath,plugin://plugin.video.themoviedb.helper/)">05</value>'';
    }
    {
      file = "1080i/Custom_1150_Search.xml";
      from = ''<param name="index" value="05"/>'';
      to = ''<param name="index" value="/"/>'';
    }

    # its rows of posters run to the screen's edge, 1920: with the skin
    # zoomed out (settings -> interface -> skin -> zoom) they stop short of
    # it, past the page's right margin. they end at the margin, 1824
    {
      file = "1080i/Includes_Home.xml";
      from = "<width>1836</width>";
      to = "<width>1740</width>";
      # both rows of posters
      count = 2;
    }
    {
      file = "1080i/Includes_Home.xml";
      from = ''<constant name="home_hub_list_w">1608</constant>'';
      to = ''<constant name="home_hub_list_w">1512</constant>'';
    }
    {
      file = "1080i/Includes_Search.xml";
      from = "<width>1836</width>";
      to = "<width>1740</width>";
    }

    # home: the spotlight 40 px up, nearer the bar, the newest row's rule 44
    # px up (760 -> 716). its column (a grouplist, it clips) to the rule, the
    # gaps in it 14 -> 10 and the title over it 4 px up with them: the
    # tallest, a 3-line title and a 3-line plot, ends 15 px over the rule
    # with the play button's frame (cut under 2 lines and 2 lines before).
    # the row's posters 36 px up (826 -> 790): the focused one's frame,
    # lifted and zoomed, went under the screen's bottom, now 30 px over it.
    # the title's 6 are the title itself and the clear probes that measure
    # how many lines it takes: they move together or the tiers are wrong
    {
      file = "1080i/Includes_Home.xml";
      from = "<visible>Integer.IsGreater(Container(9101).NumItems,0)</visible>";
      to = "<top>-40</top><visible>Integer.IsGreater(Container(9101).NumItems,0)</visible>";
    }
    {
      file = "1080i/Includes_Home.xml";
      from = "<height>592</height>";
      to = "<height>588</height>";
    }
    {
      file = "1080i/Includes_Home.xml";
      from = "<itemgap>14</itemgap>";
      to = "<itemgap>10</itemgap>";
    }
    {
      file = "1080i/Includes_Home.xml";
      from = "<top>202</top>";
      to = "<top>198</top>";
      # the title and its 5 clear probes
      count = 6;
    }
    {
      file = "1080i/Includes_Home.xml";
      from = ''<constant name="home_newest_list_y">44</constant>'';
      to = ''<constant name="home_newest_list_y">52</constant>'';
    }

    # its top bar: the menu, page names, clock and icons 16 px down, the
    # rule under them stays (the pages below it don't move). the active
    # tab's underline 20 px over the rule, was 32
    {
      file = "1080i/Constants.xml";
      from = ''<constant name="home_row_y">760</constant>'';
      to = ''<constant name="home_row_y">716</constant>'';
    }
    {
      file = "1080i/Constants.xml";
      from = ''<constant name="topbar_item_top">36</constant>'';
      to = ''<constant name="topbar_item_top">52</constant>'';
    }
    {
      file = "1080i/Constants.xml";
      from = ''<constant name="topbar_icon_top">47</constant>'';
      to = ''<constant name="topbar_icon_top">63</constant>'';
    }

    # the film page with tmdb helper and movie pipe: the cast, "similar"
    # (./majan-moviepipe.xml). "more by director", kodi's button 13, was the
    # library's films: its own id, movie pipe's page of the director
    # (./moviepipe/person.py), the name not last (kodi drops a quoted
    # name="value" at a parameter's end). "trailer", kodi's 11, played
    # ListItem.Trailer only, tmdb helper's films have none: its own id,
    # ./moviepipe/trailer.py's, tmdb's first trailer then. 11 in the row's
    # navigation too
    {
      file = "1080i/Includes.xml";
      from = ''<include file="Includes_CustomRows.xml"/>'';
      to = ''<include file="Includes_CustomRows.xml"/><include file="Includes_MoviePipe.xml"/>'';
    }
    {
      file = "1080i/Includes_VideoInfo.xml";
      from = "<onback>9010</onback>";
      to = "<onback>9010</onback><include>MoviePipe_MoreButtons</include>";
    }
    {
      file = "1080i/Includes_VideoInfo.xml";
      from = "<description>16px left / 14px top inner padding so the 5% zoom + focus frame are not clipped</description>";
      to = "<include>MoviePipe_CastList</include>";
    }
    {
      file = "1080i/Includes_VideoInfo.xml";
      from = ''
        <param name="id" value="13"/>
        				<param name="label" value="MORE BY DIRECTOR"/>
        				<param name="visible" value="!String.IsEmpty(ListItem.Director)"/>'';
      # tmdb helper's lists have no director (only its own page of a film
      # does): the page finds them in the film's crew by its tmdb id
      to = ''
        <param name="id" value="9151"/>
        				<param name="label" value="MORE BY DIRECTOR"/>
        				<param name="onclick" value="RunPlugin(plugin://plugin.video.moviepipe/?action=person&amp;film=$INFO[ListItem.UniqueID(tmdb)]&amp;type=$VAR[MoviePipe_TmdbType]&amp;name=$ESCINFO[ListItem.Director]&amp;tab=directed)"/>
        				<param name="visible" value="!String.IsEmpty(ListItem.Director) | $EXP[MoviePipe_HasTmdb]"/>'';
    }
    {
      file = "1080i/Includes_VideoInfo.xml";
      from = ''<param name="id" value="11"/>'';
      to = ''<param name="id" value="9152"/><param name="onclick" value="RunPlugin(plugin://plugin.video.moviepipe/?action=trailer&amp;type=$VAR[MoviePipe_TmdbType]&amp;tmdb=$INFO[ListItem.UniqueID(tmdb)])"/>'';
    }
    {
      file = "1080i/Includes_VideoInfo.xml";
      from = ''<param name="right1" value="11"/>'';
      to = ''<param name="right1" value="9152"/>'';
      # the play button, the trailer and "more"
      count = 3;
    }
    {
      file = "1080i/Includes_VideoInfo.xml";
      from = ''<param name="left1" value="11"/>'';
      to = ''<param name="left1" value="9152"/>'';
    }
    {
      file = "1080i/Includes_VideoInfo.xml";
      from = "<expression name=\"VidInfo_ShowTrailer\">$EXP[ShowTrailerButton] + !String.IsEmpty(ListItem.Trailer)</expression>";
      to = "<expression name=\"VidInfo_ShowTrailer\">$EXP[ShowTrailerButton] + [!String.IsEmpty(ListItem.Trailer) | [[String.IsEqual(ListItem.DBType,movie) | String.IsEqual(ListItem.DBType,tvshow)] + !String.IsEmpty(ListItem.UniqueID(tmdb))]]</expression>";
    }
    # the film page's plot: still, its last line fading when there's more
    # (MoviePipe_Text's way, ./majan-moviepipe.xml); it rolled up on its own
    # and showed the next line cut in half. enter on it: all of it, majan's
    {
      file = "1080i/Includes_VideoInfo.xml";
      from = ''
        <visible>!String.IsEmpty(ListItem.Plot) | !String.IsEmpty(ListItem.Tagline)</visible>
        				<control type="textbox">'';
      to = ''
        <visible>!String.IsEmpty(ListItem.Plot) | !String.IsEmpty(ListItem.Tagline)</visible>
        				<control type="textbox" id="9161">'';
    }
    {
      file = "1080i/Includes_VideoInfo.xml";
      # the page's, not the full plot's (it scrolls, its own count)
      from = "\t\t\t\t\t<autoscroll delay=\"6000\" time=\"3000\" repeat=\"10000\">true</autoscroll>  <!-- standard Kodi plot scroll: wait 6s, roll, pause 10s, repeat -->";
      to = "";
    }
    {
      file = "1080i/Includes_VideoInfo.xml";
      from = ''<control type="button" id="9001">'';
      to = ''<control type="image"><bottom>0</bottom><width>1080</width><height>44</height><texture colordiffuse="bg">common/gradient_bottom.png</texture><visible>Container(9161).HasNext</visible></control><control type="button" id="9001">'';
    }

    # the cast row was hidden while its list was empty, and a hidden list
    # loads nothing: when the film's own cast (kodi's, before tmdb helper's
    # took its place) was empty, as on the first pages after kodi starts,
    # the row stayed empty. it stays with tmdb helper's, "Loading…" till
    # the cast comes (./majan-moviepipe.xml)
    {
      file = "1080i/Includes_VideoInfo.xml";
      from = "<visible>Integer.IsGreater(Container(50).NumItems,0)</visible>";
      to = "<visible>Integer.IsGreater(Container(50).NumItems,0) | $EXP[MoviePipe_CastFromHelper]</visible><include>MoviePipe_CastEmpty</include>";
    }

    # home's top bar: 04 live tv, 05 discover, 06 downloads after tv shows,
    # in majan's music's place (hidden, and search and the gear don't move
    # left for it), each with its rows under the bar (./majan-moviepipe.xml).
    # the bar's items grey, white in focus (the mouse over one too), the
    # section shown white and underlined: the focus had no mark, and an
    # accent frame on it was one mark too many
    {
      file = "1080i/Includes_Home.xml";
      from = ''
        <textcolor>text_secondary</textcolor>
        					<label>$PARAM[index]</label>
        					<visible>!$PARAM[active]</visible>
        				</control>'';
      to = ''
        <textcolor>text_secondary</textcolor>
        					<label>$PARAM[index]</label>
        					<visible>!$PARAM[active] + !Control.HasFocus($PARAM[id])</visible>
        				</control>
        				<control type="label">
        					<left>0</left>
        					<top>4</top>
        					<width>topbar_index_w</width>
        					<height>topbar_item_h</height>
        					<font>mono_14</font>
        					<textcolor>text_primary</textcolor>
        					<label>$PARAM[index]</label>
        					<visible>!$PARAM[active] + Control.HasFocus($PARAM[id])</visible>
        				</control>'';
    }
    {
      file = "1080i/Includes_Home.xml";
      from = ''
        <font>menu_26_medium</font>
        					<textcolor>text_secondary</textcolor>
        					<label>$PARAM[label]</label>
        					<visible>!$PARAM[active]</visible>
        				</control>'';
      to = ''
        <font>menu_26_medium</font>
        					<textcolor>text_secondary</textcolor>
        					<label>$PARAM[label]</label>
        					<visible>!$PARAM[active] + !Control.HasFocus($PARAM[id])</visible>
        				</control>
        				<control type="label">
        					<left>topbar_label_x</left>
        					<top>0</top>
        					<width>200</width>
        					<height>topbar_item_h</height>
        					<font>menu_26_medium</font>
        					<textcolor>text_primary</textcolor>
        					<label>$PARAM[label]</label>
        					<visible>!$PARAM[active] + Control.HasFocus($PARAM[id])</visible>
        				</control>'';
    }
    {
      # search's and the gear's: white in focus already, the frame goes
      file = "1080i/Includes_Home.xml";
      from = ''
        <include content="Majan_FocusFrameAlways">
        					<param name="visible" value="Control.HasFocus($PARAM[id])"/>
        				</include>'';
      to = "";
    }
    {
      # down from 04 05 06: their rows
      file = "1080i/Includes_Home.xml";
      from = ''<ondown condition="$EXP[Home_HubMusic]">9231</ondown>'';
      to = ''<ondown condition="$EXP[Home_HubMusic]">9231</ondown><ondown condition="$EXP[MoviePipe_HubLive]">9251</ondown><ondown condition="$EXP[MoviePipe_HubDiscover]">9261</ondown><ondown condition="$EXP[MoviePipe_HubDownloads]">9271</ondown>'';
    }
    {
      file = "1080i/Home.xml";
      from = "<include>Home_HubMusic</include>";
      to = "<include>Home_HubMusic</include><include>MoviePipe_Hubs</include>";
    }
    {
      file = "1080i/Includes_Home.xml";
      from = ''<param name="shown" value="!Skin.HasSetting(HideMenu.Music)"/>'';
      to = ''<param name="shown" value="false"/>'';
    }
    {
      file = "1080i/Includes_Home.xml";
      # music's: hidden, the way from tv shows goes through it
      from = ''<param name="onright" value="9005"/>'';
      to = ''<param name="onright" value="9007"/>'';
    }
    {
      file = "1080i/Includes_Home.xml";
      # search's
      from = ''<param name="onleft" value="9004"/>'';
      to = ''<param name="onleft" value="9009"/>'';
    }
    {
      file = "1080i/Includes_Home.xml";
      from = ''<param name="d4" value="157"/>'';
      to = ''<param name="d4" value="0"/>'';
      # search and the gear
      count = 2;
    }
    {
      file = "1080i/Includes_Home.xml";
      from = "<!-- Search: Majan search window (Custom_1150_Search.xml) -->";
      to = "<include>MoviePipe_MenuItems</include><!-- Search: Majan search window (Custom_1150_Search.xml) -->";
    }
    {
      file = "1080i/Constants.xml";
      from = ''<constant name="menu_x_search">783</constant>'';
      to = ''<constant name="menu_x_search">1252</constant>'';
    }
    {
      file = "1080i/Constants.xml";
      from = ''<constant name="menu_x_gear">865</constant>'';
      to = ''<constant name="menu_x_gear">1334</constant>'';
    }
    {
      # the gear's menu drops under it, 25 px left of it: the gear moved 469
      file = "1080i/Custom_1151_SystemMenu.xml";
      from = "<left>840</left>";
      to = "<left>1309</left>";
    }
  ];

  # a third font in kodi's settings -> interface -> skin -> fonts, "JetBrains
  # Mono" (nl, the quickshell font): majan's own grotesk and display fonts
  # have no cyrillic, its fontset with jetbrains in place of both, 12%
  # smaller (a monospace is wider; majan's mono and number fonts stay). the
  # copy is its own "Default" set: a fontset is only what it lists
  font = {
    set = "JetBrains Mono";
    scale = 0.88;
    files = [
      "JetBrainsMonoNLNerdFont-Regular.ttf"
      "JetBrainsMonoNLNerdFont-Medium.ttf"
      "JetBrainsMonoNLNerdFont-SemiBold.ttf"
      "JetBrainsMonoNLNerdFont-Bold.ttf"
      "JetBrainsMonoNLNerdFont-ExtraBold.ttf"
    ];
    families = [
      {
        from = "HankenGrotesk-";
        to = "JetBrainsMonoNLNerdFont-";
      }
      {
        from = "MajanDisplay-ExtraBold";
        to = "JetBrainsMonoNLNerdFont-ExtraBold";
      }
    ];
  };
}
