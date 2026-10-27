# where the download pipeline lives, for ./default.nix and kodi's add-on
# (../kodi/moviepipe). every web ui is on 127.0.0.1 only
rec {
  qbittorrent = 8140; # jedha's is 8129 through jedha-tunnel.nix
  radarr = 7878;
  sonarr = 8989;
  prowlarr = 9696;
  bazarr = 6767;
  flaresolverr = 8191;
  # rutracker past cloudflare (./default.nix)
  rutracker = 8150;
  # qbittorrent's own port for peers, open in the firewall
  torrenting = 51413;

  disk = "/media/outer-1";
  movies = "${disk}/movies";
  series = "${disk}/series";
  # torrents seed from here, the library gets hardlinks: same disk
  downloads = "${disk}/downloads";

  state = "/var/lib/arr";
  # an api key per app, made once (./default.nix, arr-keys)
  keys = "${state}/keys";
  # english subtitles waiting for russian (./subtitles.py)
  queue = "${state}/subtitles";
}
