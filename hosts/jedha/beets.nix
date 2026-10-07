{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ beets ffmpeg ];
  environment.variables.BEETSDIR = "/var/lib/beets";

  systemd.tmpfiles.rules = [ "d /var/lib/beets 0700 root root -" ];

  sops.secrets.navidrome_password = { };

  sops.templates."beets-config" = {
    path = "/var/lib/beets/config.yaml";
    content = ''
      directory: /var/lib/media/music
      library: /var/lib/beets/library.db

      import:
        copy: no
        move: no
        write: yes
        resume: ask
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

      plugins: chroma musicbrainz mbsync spotify deezer lyrics fetchart embedart lastgenre duplicates info missing edit subsonicupdate fromfilename scrub replaygain unimported

      paths:
        default: $albumartist/$album%aunique{}/$track $title
        singleton: $artist/Singles/$title
        comp: Compilations/$album%aunique{}/$track $title

      clutter: ["Thumbs.DB", ".DS_Store", "cover.jpg", "cover.png"]

      chroma:
        auto: yes
      fetchart:
        auto: yes
      embedart:
        auto: yes

      subsonic:
        url: http://127.0.0.1:4533
        user: ТВОЙ_ЮЗЕР
        pass: '${config.sops.placeholder.navidrome_password}'
        auth: token

      subsonicplaylist:
        base_url: http://127.0.0.1:4533
        username: ТВОЙ_ЮЗЕР
        password: '${config.sops.placeholder.navidrome_password}'
        playlist_names: ["delete"]
        delete: yes

      ignore: ['_RETTUNG_*', '.*', '*.tmp', '*.part', 'lost+found']
      ignore_hidden: yes
    '';
  };
}
