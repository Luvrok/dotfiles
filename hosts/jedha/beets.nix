{ config, pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ beets ffmpeg ];
  systemd.services.beets-auto.path = with pkgs; [ beets ffmpeg ];
  environment.variables.BEETSDIR = "/var/lib/beets";

  systemd.tmpfiles.rules = [ "d /var/lib/beets 0700 root root -" ];

  sops.secrets.navidrome_password = { };

  sops.templates."beets-config" = {
    path = "/var/lib/beets/config.yaml";
    content = ''
      directory: /var/lib/media/music
      library: /var/lib/beets/library.db

      import:
        move: yes
        write: yes
        quiet_fallback: skip
        log: /var/lib/beets/import.log

      plugins: musicbrainz fetchart embedart subsonicupdate subsonicplaylist

      paths:
        default: $albumartist/$album%aunique{}/$track $title
        singleton: $artist/Singles/$title
        comp: Compilations/$album%aunique{}/$track $title

      clutter: ["Thumbs.DB", ".DS_Store", "cover.jpg", "cover.png"]

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
    '';
  };
}
