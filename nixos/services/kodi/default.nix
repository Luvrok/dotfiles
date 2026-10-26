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
  # the provider breaks tmdb: kodi's own downloads (posters, curl takes
  # the proxy from the environment when kodi's setting is off) and the
  # scrapers' (python's urllib) go through xray's mixed inbound
  # (hosts/barnard/xray.nix). no internet in kodi while xray is off
  proxy = "http://127.0.0.1:10808";
  kodi = pkgs.symlinkJoin {
    name = "kodi-xray";
    paths = [ pkgs.kodi-wayland ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/kodi \
        --set http_proxy ${proxy} \
        --set https_proxy ${proxy} \
        --set no_proxy localhost,127.0.0.1,::1
    '';
  };
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
        "${datadir}/addons/skin.estuary".source = pkgs.callPackage ./skin.nix {
          kodi = pkgs.kodi-wayland;
        };

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
      # to look again when a video under the sources is new: copied, moved
      # in or done downloading since the last time. one still being written
      # (changed in the last 5 minutes) waits for the next run, a torrent
      # that's downloading would rescan every 10 minutes and the lists would
      # reload their posters each time
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
                # a window of time, (the last run, now] both 5 minutes back.
                # ctime, a move or a copy that keeps the mtime counts too
                settled=$(($(date +%s) - 300))
                if [ -e "$stamp" ] && [ -z "$(find ${movies} ${series} -type f \
                  \( -iname '*.mkv' -o -iname '*.mp4' -o -iname '*.avi' -o -iname '*.m4v' \) \
                  -cnewer "$stamp" ! -newerct "@$settled" -print -quit 2>/dev/null)" ]; then
                  touch -d "@$settled" "$stamp"
                  exit 0
                fi
                mkdir -p "$(dirname "$stamp")"
                touch -d "@$settled" "$stamp"
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
