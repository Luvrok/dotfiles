{ config, pkgs, ... }:

{
  imports = [
    ./betanin.nix
    ./metube.nix
  ];

  environment.systemPackages = with pkgs; [
    beets
    ffmpeg
  ];

  environment.variables.BEETSDIR = "/var/lib/beets";
  environment.shellAliases.beet = "sudo -u beets --preserve-env=BEETSDIR,http_proxy,https_proxy,no_proxy beet";

  users.users.beets = {
    isSystemUser = true;
    group = "media";
    home = "/var/lib/beets";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/beets 0700 beets media -"
    "Z /var/lib/beets - beets media -"
  ];

  sops.secrets = {
    navidrome_password = { };
    "lyrics/genius_api_key" = { };
  };

  # spotify plugin turn in
  sops.templates."beets-config" = {
    path = "/var/lib/beets/config.yaml";
    owner = "beets";
    content = ''
      directory: /var/lib/media/music
      library: /var/lib/beets/library.db

      import:
        copy: yes
        move: no
        write: yes
        resume: ask
        detail: yes
        duplicate_verbose_prompt: yes
        quiet_fallback: skip
        log: /var/lib/beets/import.log

      match:
        strong_rec_thresh: 0.04
        medium_rec_thresh: 0.10
        rec_gap_thresh: 0.10
        max_rec:
          missing_tracks: medium
          unmatched_tracks: medium
        ignored: []
        preferred:
          media: ['Digital Media|File', 'CD']
          original_year: yes

      plugins: chroma musicbrainz mbsync deezer lyrics fetchart embedart lastgenre duplicates info missing edit subsonicupdate subsonicplaylist fromfilename scrub replaygain unimported

      paths:
        default: $albumartist/$album%aunique{}/$track $title
        singleton: $artist/Singles/$title
        comp: Compilations/$album%aunique{}/$track $title

      clutter: ["Thumbs.DB", ".DS_Store", "cover.jpg", "cover.png"]

      chroma:
        auto: yes

      fetchart:
        auto: yes
        minwidth: 500
        maxwidth: 1500

      embedart:
        auto: yes
        maxwidth: 1000

      musicbrainz:
        data_source_mismatch_penalty: 0.0

      replaygain:
        backend: ffmpeg

      lyrics:
        synced: yes
        sources: [lrclib, genius]
        genius_api_key: '${config.sops.placeholder."lyrics/genius_api_key"}'

      lastgenre:
        count: 3
        force: yes

      unimported:
        ignore_extensions: jpg png

      subsonic:
        url: http://127.0.0.1:4533
        user: morturion
        pass: '${config.sops.placeholder.navidrome_password}'
        auth: token

      subsonicplaylist:
        base_url: http://127.0.0.1:4533
        username: morturion
        password: '${config.sops.placeholder.navidrome_password}'
        playlist_names: ["delete"]
        delete: yes

      ignore: ['_RETTUNG_*', '.*', '*.tmp', '*.part', 'lost+found']
      ignore_hidden: yes
    '';
  };

  systemd.services.beets-trash = {
    description = "Remove tracks listed in the Navidrome playlist 'delete'";
    path = [ pkgs.beets ];
    environment.BEETSDIR = "/var/lib/beets";
    serviceConfig = {
      Type = "oneshot";
      User = "beets";
      Group = "media";
      UMask = "0002";
    };
    script = ''
      beet subsonicplaylist
      beet remove -d -f 'subsonic_playlist:;delete;'
    '';
  };

  systemd.timers.beets-trash = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
    };
  };
}
