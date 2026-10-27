# kodi: the library of /media/outer-1, posters and plots from tmdb (its
# scrapers come with kodi). a video plays in mpv, in mpv's own window with
# mpv's config, scripts and keys, tv and streams in kodi's player. majan,
# tmdb helper, the downloads of ../arr in the menu of a film or a show and
# on enter in tmdb helper, tv channels (./addons.nix), other add-ons from
# inside kodi.
# barnard only, its env.nix imports this
{
  lib,
  pkgs,
  inputs,
  username,
  ...
}:

let
  kodiPackages = pkgs.kodi-wayland.packages;
  addons = kodiPackages.callPackage ./addons.nix { inherit inputs; };
  # the add-ons and what they need, to turn on in kodi
  addonIds = map (a: a.namespace) (kodiPackages.requiredKodiAddons addons);
  kodiWithAddons = pkgs.kodi-wayland.withPackages (_: addons);

  # tmdb through xray's mixed inbound (hosts/barnard/xray.nix) when the
  # provider breaks it: kodi's curl (posters) and the scrapers' urllib
  # take the proxy from the environment. no internet in kodi while xray
  # is off
  useProxy = false;
  proxy = "http://127.0.0.1:10808";
  kodi =
    if useProxy then
      pkgs.symlinkJoin {
        name = "kodi-xray";
        paths = [ kodiWithAddons ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/kodi \
            --set http_proxy ${proxy} \
            --set https_proxy ${proxy} \
            --set no_proxy localhost,127.0.0.1,::1
        '';
      }
    else
      kodiWithAddons;

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
  player =
    action: name: priority:
    let
      run =
        query: "executebuiltin://RunPlugin(plugin://plugin.video.moviepipe/?action=${action}&${query})";
    in
    builtins.toJSON {
      name = "Movie pipe: ${name}";
      plugin = "plugin.video.moviepipe";
      inherit priority;
      is_resolvable = "false";
      play_movie = run "type=movie&tmdb={tmdb}";
      play_episode = run "type=episode&tmdb={tmdb}&season={season}&episode={episode}";
    };

  defaults = pkgs.writeText "kodi-defaults.json" (
    builtins.toJSON {
      settings = {
        "lookandfeel.skin" = "skin.majan";
        # ./majan.nix's, majan's own have no cyrillic
        "lookandfeel.font" = "JetBrains Mono";
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
  home-manager.users.${username} =
    # home-manager's lib, it has lib.hm
    { config, lib, ... }:
    let
      datadir = config.programs.kodi.datadir;
      # kodi puts its libraries (rtmpdump, libnfs...) in LD_LIBRARY_PATH,
      # mpv shouldn't load them over its own, nor take kodi's proxy. --
      # for a file that starts with a dash
      mpv = pkgs.writeShellScript "kodi-mpv" ''
        unset LD_LIBRARY_PATH http_proxy https_proxy no_proxy
        exec ${config.programs.mpv.finalPackage}/bin/mpv -- "$1"
      '';
    in
    {
      programs.kodi = {
        enable = true;
        package = kodi;
        # set what each one is once in kodi: movies -> set content ->
        # movies, series -> tv shows. kodi keeps that in its database
        sources.video.source = [
          {
            name = "Movies";
            path = "/media/outer-1/movies/";
            allowsharing = "true";
          }
          {
            name = "Series";
            path = "/media/outer-1/series/";
            allowsharing = "true";
          }
        ];
      };

      home.file = {
        # vim keys (./keyboard.xml)
        "${datadir}/userdata/keymaps/keyboard.xml".source = ./keyboard.xml;

        # enter on a film or an episode in tmdb helper asks which player:
        # these two, ./moviepipe's actions. tmdb helper fills {tmdb} (the
        # show's for an episode), {season} and {episode}
        "${datadir}/userdata/addon_data/plugin.video.themoviedb.helper/players/moviepipe-pick.json".text =
          player "pick" "Pick a release…"
            1;
        "${datadir}/userdata/addon_data/plugin.video.themoviedb.helper/players/moviepipe-download.json".text =
          player "download" "Download" 2;

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

      # kodi installs the add-ons switched off (./enable-addons.py), its
      # first settings: ./defaults.py
      home.activation.kodiAddons = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.python3}/bin/python3 ${./enable-addons.py} ${datadir} ${lib.concatStringsSep " " addonIds}
        run ${pkgs.python3}/bin/python3 ${./defaults.py} ${datadir} ${defaults}
      '';
    };
}
