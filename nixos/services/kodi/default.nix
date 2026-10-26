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
      movies = "/media/outer-1/movies/";
      series = "/media/outer-1/series/";
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
            path = movies;
            allowsharing = "true";
          }
          {
            name = "Series";
            path = series;
            allowsharing = "true";
          }
        ];
        # nixos updates kodi, not its own check
        addonSettings."service.xbmc.versioncheck".versioncheck_enable = "false";
      };

      # what the scraper didn't find (./missing.py)
      home.packages = [
        (pkgs.writers.writePython3Bin "kodi-missing" {
          flakeIgnore = [
            "E203"
            "E501"
          ];
        } (builtins.readFile ./missing.py))
      ];

      home.file = {
        # kodi takes this one over its own estuary (./skin.nix)
        "${datadir}/addons/skin.estuary".source = pkgs.callPackage ./skin.nix { inherit kodi; };

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

      # kodi looks for new files when it starts. while it runs, this asks it
      # every 10 minutes if something on the disk changed since the last
      # time. kodi skips what it has already, a show it didn't find it
      # searches again
      systemd.user.services.kodi-update = {
        Unit.Description = "Kodi library update when the sources change";
        Service = {
          Type = "oneshot";
          ExecStart = lib.getExe (
            pkgs.writeShellApplication {
              name = "kodi-update";
              runtimeInputs = [
                pkgs.procps
                pkgs.findutils
                pkgs.coreutils
                kodi
              ];
              text = ''
                pgrep -u "$USER" -x kodi.bin >/dev/null || exit 0
                stamp=''${XDG_STATE_HOME:-$HOME/.local/state}/kodi-update
                if [ -e "$stamp" ] && [ -z "$(find ${movies} ${series} -newer "$stamp" -print -quit 2>/dev/null)" ]; then
                  exit 0
                fi
                mkdir -p "$(dirname "$stamp")"
                touch "$stamp"
                kodi-send -a "UpdateLibrary(video)" >/dev/null
              '';
            }
          );
        };
      };
      systemd.user.timers.kodi-update = {
        Timer.OnCalendar = "*:0/10";
        Install.WantedBy = [ "timers.target" ];
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
