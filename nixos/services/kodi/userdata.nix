# what kodi reads in its userdata (./default.nix sets the package up):
# vim keys, tmdb helper's player for ./moviepipe, torrent names for the
# scraper, a video file going to mpv, the tv channels of iptv simple. the
# settings it can't be handed as plain files (majan first, the channels on
# the first run) are ./userdata.py's, written at the end of this file
{ addonIds }:
{
  config,
  lib,
  pkgs,
  ...
}:

let
  datadir = config.programs.kodi.datadir;

  # the tv channels: one m3u of every list below, made by ./channels.py
  # (kodi-channels.timer, at login and once a day). nothing left out, a list
  # a group; a link that doesn't open gets "✗ " before its name. fixes: a
  # channel's link by its name, where a list's is gone (channel one: its
  # player on 1tv.ru, e= is when the link ends and the server checks only
  # that, 2000000000 is 2033; russia 24: smotrim like russia 1). channel
  # one is dash, inputstream.adaptive's (./addons.nix). kodi goes
  # straight, from a russian ip: foreign channels are often geo-blocked
  freeTv = country: "https://raw.githubusercontent.com/Free-TV/IPTV/master/playlists/playlist_${country}.m3u8";
  iptvOrg = path: "https://iptv-org.github.io/iptv/${path}.m3u";
  channelsConfig = pkgs.writeText "kodi-channels.json" (
    builtins.toJSON {
      # a group: its lists. a country: iptv-org's and free-tv's (where it
      # has one). the west, australia and new zealand, east asia, argentina,
      # russia. then the
      # topics across countries
      lists =
        let
          country = code: freeTvName: [ (iptvOrg "countries/${code}") ] ++ lib.optional (freeTvName != null) (freeTv freeTvName);
        in
        {
          "Russia" = country "ru" "russia";
          "UK" = country "uk" "uk";
          "USA" = country "us" "usa";
          "Canada" = country "ca" "canada";
          "Australia" = country "au" "australia";
          "New Zealand" = country "nz" null;
          "Ireland" = country "ie" "ireland";
          "Germany" = country "de" "germany";
          "Austria" = country "at" "austria";
          "Switzerland" = country "ch" "switzerland";
          "France" = country "fr" "france";
          "Belgium" = country "be" "belgium";
          "Netherlands" = country "nl" "netherlands";
          "Luxembourg" = country "lu" "luxembourg";
          "Italy" = country "it" "italy";
          "Spain" = country "es" "spain";
          "Portugal" = country "pt" "portugal";
          "Denmark" = country "dk" "denmark";
          "Sweden" = country "se" "sweden";
          "Norway" = country "no" "norway";
          "Finland" = country "fi" "finland";
          "Iceland" = country "is" "iceland";
          "Japan" = country "jp" "japan";
          "South Korea" = country "kr" "korea";
          "North Korea" = country "kp" "north_korea";
          "China" = country "cn" "china";
          "Argentina" = country "ar" "argentina";
          "Movies" = [
            (iptvOrg "categories/movies")
            (freeTv "zz_movies")
          ];
          "News" = [
            (iptvOrg "categories/news")
            (freeTv "zz_news_en")
          ];
        };
      fixes =
        let
          firstChannel = "https://cdn8.1internet.tv/dash-live3/streams/1tv-dvr/1tvdash.mpd?e=2000000000";
          russia24 = "https://live.smotrim.ru/vgtrk/0/russia24-hd/index.m3u8";
        in
        {
          "Первый канал" = firstChannel;
          "Channel One" = firstChannel;
          "Channel One Russia" = firstChannel;
          "Perviy Kanal" = firstChannel;
          "Pervyy Kanal" = firstChannel;
          "Россия-24" = russia24;
          "Россия 24" = russia24;
          "Russia 24" = russia24;
          "Rossiya 24" = russia24;
        };
      timeout = 8;
      workers = 64;
    }
  );
  channelsFile = "${config.xdg.dataHome}/kodi-channels/channels.m3u";
  # iptv simple reads it again every hour, a new day's check shows
  instance = ''
    <settings version="2">
      <setting id="kodi_addon_instance_name">TV</setting>
      <setting id="kodi_addon_instance_enabled">true</setting>
      <setting id="m3uPathType">0</setting>
      <setting id="m3uPath">${channelsFile}</setting>
      <setting id="m3uRefreshMode">1</setting>
      <setting id="m3uRefreshIntervalMins">60</setting>
    </settings>
  '';

  # kodi puts its libraries (rtmpdump, libnfs...) in LD_LIBRARY_PATH, mpv
  # shouldn't load them over its own, nor take kodi's proxy. -- for a file
  # that starts with a dash
  mpv = pkgs.writeShellScript "kodi-mpv" ''
    unset LD_LIBRARY_PATH http_proxy https_proxy no_proxy
    exec ${config.programs.mpv.finalPackage}/bin/mpv -- "$1"
  '';

  # what kodi's own settings are on a first run: majan and its font (no
  # cyrillic otherwise, ./majan-patches.nix), no ".." first in a list
  # (majan's page showed "Back" over a show's seasons, back is a key)
  defaults = pkgs.writeText "kodi-defaults.json" (
    builtins.toJSON {
      settings = {
        "lookandfeel.skin" = "skin.majan";
        "lookandfeel.font" = "JetBrains Mono";
        "filelists.showparentdiritems" = "false";
      };
      files."userdata/addon_data/pvr.iptvsimple/instance-settings-1.xml" = instance;
      # the lists that were an instance each: gone, if kodi has nothing else
      # in them that was changed
      gone = map (n: "userdata/addon_data/pvr.iptvsimple/instance-settings-${toString n}.xml") [
        2
        3
        4
        5
      ];
    }
  );
in
{
  home.file = {
    # vim keys (./keyboard.xml)
    "${datadir}/userdata/keymaps/keyboard.xml".source = ./keyboard.xml;

    # enter on a film or an episode in tmdb helper: ./moviepipe's
    # "Download…", the releases to pick one of. tmdb helper fills {tmdb} (the
    # show's for an episode), {season} and {episode}
    "${datadir}/userdata/addon_data/plugin.video.themoviedb.helper/players/moviepipe-download.json".source =
      ./moviepipe-player.json;

    # torrent names the scraper finds
    "${datadir}/userdata/advancedsettings.xml".source = ./advancedsettings.xml;

    # a video file goes to mpv. kodi runs it through sh with the path in
    # double quotes, a " $ ` or \ in a file name breaks it. mpv resumes
    # where it was (save-position-on-quit). kodi marked it watched after
    # 10 seconds of mpv: never now (playcountminimumtime), only by hand (w,
    # ./keyboard.xml). tv and the streams of add-ons stay in kodi's
    # player, the first rule that matches wins
    "${datadir}/userdata/playercorefactory.xml".text = ''
      <playercorefactory>
        <players>
          <player name="mpv" type="ExternalPlayer" audio="false" video="true">
            <filename>${mpv}</filename>
            <args>"{1}"</args>
            <hidexbmc>false</hidexbmc>
            <playcountminimumtime>2147483647</playcountminimumtime>
          </player>
        </players>
        <rules action="prepend">
          <rule protocols="pvr" player="VideoPlayer"/>
          <rule internetstream="true" player="VideoPlayer"/>
          <rule video="true" player="mpv"/>
        </rules>
      </playercorefactory>
    '';
  };

  # kodi installs the add-ons switched off and starts with its own settings:
  # ./userdata.py puts what majan and the channels need in place
  home.activation.kodiUserdata = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    run ${pkgs.python3}/bin/python3 ${./userdata.py} enable ${datadir} ${lib.escapeShellArgs addonIds}
    run ${pkgs.python3}/bin/python3 ${./userdata.py} defaults ${datadir} ${defaults}
  '';

  # tmdb helper plays a second of its dummy.mp4 before a player that isn't a
  # file (ours above), and a file plays in mpv: only its strm files get the
  # dummy. its lists of a person's films 60 a page, not 20
  # (./moviepipe/person.py). 10 requests at a time, not as many as a list
  # has (20 a row, discover's rows at once): on a slow line a few of them
  # timed out (15 s), two timeouts in 45 s and tmdb helper asks tmdb
  # nothing for 15 s, a 429 the same: rows and posters stayed empty.
  # "medium" art: posters w500, fanart w1280, not w780 and the original
  # (megabytes each) for a 140 px poster and a blurred backdrop. a symlink
  # into the store: these can't be changed from kodi's gui, its other
  # settings can't be kept either
  programs.kodi.addonSettings."plugin.video.themoviedb.helper" = {
    only_resolve_strm = "true";
    pagemulti_sync = "3";
    max_threads = "10";
    artwork_quality = "2";
  };

  systemd.user.services.kodi-channels = {
    Unit.Description = "Kodi's tv channels, checked";
    Unit.After = [ "network-online.target" ];
    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.python3}/bin/python3 ${./channels.py} ${channelsConfig} ${channelsFile}";
      Nice = 10;
    };
  };
  systemd.user.timers.kodi-channels = {
    Unit.Description = "Kodi's tv channels, checked once a day";
    Timer = {
      OnStartupSec = "1min";
      OnUnitActiveSec = "1d";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
