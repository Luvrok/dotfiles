# kodi: the library of /media/outer-1, posters and plots from tmdb (its
# scrapers come with kodi). a video plays in mpv, in mpv's own window with
# mpv's config, scripts and keys. kodi's own settings, KarmaMole's skins
# (./skins.nix) next to estuary, other add-ons from inside kodi. barnard
# only, its env.nix imports this
{
  pkgs,
  inputs,
  username,
  ...
}:

let
  kodiPackages = pkgs.kodi-wayland.packages;
  skins = kodiPackages.callPackage ./skins.nix { inherit inputs; };
  # the skins and what they need, to turn on in kodi
  addonIds = map (a: a.namespace) (kodiPackages.requiredKodiAddons skins);
  kodiWithSkins = pkgs.kodi-wayland.withPackages (_: skins);

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
        paths = [ kodiWithSkins ];
        nativeBuildInputs = [ pkgs.makeWrapper ];
        postBuild = ''
          wrapProgram $out/bin/kodi \
            --set http_proxy ${proxy} \
            --set https_proxy ${proxy} \
            --set no_proxy localhost,127.0.0.1,::1
        '';
      }
    else
      kodiWithSkins;
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
        # torrent names the scraper finds
        "${datadir}/userdata/advancedsettings.xml".source = ./advancedsettings.xml;

        # every video goes to mpv. kodi runs it through sh with the path in
        # double quotes, a " $ ` or \ in a file name breaks it. mpv resumes
        # where it was (save-position-on-quit), kodi marks it watched after
        # 10 seconds of mpv
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
              <rule video="true" player="mpv"/>
            </rules>
          </playercorefactory>
        '';
      };

      # kodi installs the skins switched off (./enable-addons.py)
      home.activation.kodiAddons = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.python3}/bin/python3 ${./enable-addons.py} ${datadir} ${lib.concatStringsSep " " addonIds}
      '';
    };
}
