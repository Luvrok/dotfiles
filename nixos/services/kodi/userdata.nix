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

  # iptv simple's lists, iptv-org's free channels: tv -> channels, by group.
  # an instance per list, its settings in kodi after the first time
  channels = {
    "Russia" = "https://iptv-org.github.io/iptv/countries/ru.m3u";
    "News" = "https://iptv-org.github.io/iptv/categories/news.m3u";
  };
  instance = name: ''
    <settings version="2">
      <setting id="kodi_addon_instance_name">${name}</setting>
      <setting id="kodi_addon_instance_enabled">true</setting>
      <setting id="m3uPathType">1</setting>
      <setting id="m3uUrl">${channels.${name}}</setting>
    </settings>
  '';

  # enter on a film or an episode in tmdb helper: ./moviepipe's
  # "Download…", the releases to pick one of. tmdb helper fills {tmdb} (the
  # show's for an episode), {season} and {episode}
  player =
    let
      run = query: "executebuiltin://RunPlugin(plugin://plugin.video.moviepipe/?action=download&${query})";
    in
    builtins.toJSON {
      name = "Movie pipe: Download…";
      plugin = "plugin.video.moviepipe";
      priority = 1;
      is_resolvable = "false";
      play_movie = run "type=movie&tmdb={tmdb}";
      play_episode = run "type=episode&tmdb={tmdb}&season={season}&episode={episode}";
    };

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
      files = builtins.listToAttrs (
        lib.imap1 (n: name: {
          name = "userdata/addon_data/pvr.iptvsimple/instance-settings-${toString n}.xml";
          value = instance name;
        }) (builtins.attrNames channels)
      );
    }
  );
in
{
  home.file = {
    # vim keys (./keyboard.xml)
    "${datadir}/userdata/keymaps/keyboard.xml".source = ./keyboard.xml;

    # enter on a film or an episode in tmdb helper: download, a release picked
    "${datadir}/userdata/addon_data/plugin.video.themoviedb.helper/players/moviepipe-download.json".text =
      player;

    # torrent names the scraper finds
    "${datadir}/userdata/advancedsettings.xml".source = ./advancedsettings.xml;

    # a video file goes to mpv. kodi runs it through sh with the path in
    # double quotes, a " $ ` or \ in a file name breaks it. mpv resumes
    # where it was (save-position-on-quit), kodi marks it watched after
    # 10 seconds of mpv. tv and the streams of add-ons stay in kodi's
    # player, the first rule that matches wins
    "${datadir}/userdata/playercorefactory.xml".text = ''
      <playercorefactory>
        <players>
          <player name="mpv" type="ExternalPlayer" audio="false" video="true">
            <filename>${mpv}</filename>
            <args>"{1}"</args>
            <hidexbmc>false</hidexbmc>
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
  # (./moviepipe/person.py). a symlink into the store: these two can't be
  # changed from kodi's gui, its other settings can't be kept either
  programs.kodi.addonSettings."plugin.video.themoviedb.helper" = {
    only_resolve_strm = "true";
    pagemulti_sync = "3";
  };
}
