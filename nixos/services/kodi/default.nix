# kodi: the library of /media/outer-1, posters and plots from tmdb (its
# scrapers come with kodi). a video plays in mpv, in mpv's own window with
# mpv's config, scripts and keys, kodi waits under it. estuary in the
# quickshell colors (./skin.nix). barnard only, its env.nix imports this
{
  pkgs,
  username,
  ...
}:

let
  kodi = pkgs.kodi-wayland;
in
{
  home-manager.users.${username} =
    # home-manager's lib, it has lib.hm
    { config, lib, ... }:
    let
      datadir = config.programs.kodi.datadir;
      # kodi puts its libraries (rtmpdump, libnfs...) in LD_LIBRARY_PATH,
      # mpv shouldn't load them over its own. -- for a file that starts
      # with a dash
      mpv = pkgs.writeShellScript "kodi-mpv" ''
        unset LD_LIBRARY_PATH
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
        # nixos updates kodi, not its own check
        addonSettings."service.xbmc.versioncheck".versioncheck_enable = "false";
      };

      home.file = {
        # kodi takes this one over its own estuary (./skin.nix)
        "${datadir}/addons/skin.estuary".source = pkgs.callPackage ./skin.nix { inherit kodi; };

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

      # new files show up when kodi starts, no dialog while it looks. no
      # clicks on every key
      home.activation.kodiSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${pkgs.python3}/bin/python3 ${./guisettings.py} ${datadir}/userdata/guisettings.xml \
          videolibrary.updateonstartup=true \
          videolibrary.backgroundupdate=true \
          lookandfeel.soundskin=
      '';
    };
}
