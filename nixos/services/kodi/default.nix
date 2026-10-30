# kodi: the library of /media/outer-1, posters and plots from tmdb (its
# scrapers come with kodi). a video plays in mpv, in mpv's own window with
# mpv's config, scripts and keys, tv and streams in kodi's player. majan,
# tmdb helper, the downloads of ../arr in the menu of a film or a show and
# on enter in tmdb helper, tv channels (./addons.nix), other add-ons from
# inside kodi. barnard only, its env.nix imports this
#
# ./package.nix: the kodi package with the add-ons, ./userdata.nix: what
# kodi reads in its userdata, ./majan.nix and ./moviepipe: the skin and the
# add-on of the downloads
{
  pkgs,
  inputs,
  username,
  ...
}:

let
  kodi = import ./package.nix { inherit pkgs inputs; };
in
{
  # kodi's settings -> regional -> timezone lists the zones of
  # /usr/share/zoneinfo/zone.tab, nixos has none: the list was empty and
  # the setting looked locked to the system's (time.timeZone). kodi's own
  # zone is its alone (it sets TZ for itself)
  systemd.tmpfiles.rules = [ "L /usr/share/zoneinfo - - - - ${pkgs.tzdata}/share/zoneinfo" ];

  home-manager.users.${username} = {
    imports = [ (import ./userdata.nix { inherit (kodi) addonIds; }) ];

    programs.kodi = {
      enable = true;
      inherit (kodi) package;
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
  };
}
