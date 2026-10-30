#!/usr/bin/env bash
# a kodi from this working tree, no switch (./default.nix). its home is
# $STATE (/tmp/kodi-test), barnard's ~/.kodi stays as it is.
#   run.sh start         build it and start it: on a screen of xvfb (:99)
#                        with ./mock.py; LIVE=1: a window here, real tmdb
#   run.sh stop
#   run.sh shot NAME     the screen to $STATE/shots/NAME.png
#   run.sh key KEY...    xdotool's names: Right, Return, BackSpace, i, 5...
#   run.sh type TEXT
#   run.sh log [N]       kodi's log; errs [N]: its errors and warnings
#   run.sh library       a dozen films for home (mock, kodi stopped); f scans
#   run.sh xray [S]      a slow xray (S s a tunnel, 8) and an image.tmdb.org
#                        of the mock's pictures (./xray.py): kodi's pictures
#                        through ../moviepipe/images.py from the next start.
#                        rm -r $STATE/xray: straight again
# a change to ../ is stop, start again (kodi reads its add-ons at start)
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
REPO=$(cd "$HERE/.." && pwd)
STATE=${STATE:-/tmp/kodi-test}
LIVE=${LIVE:-}
D=$STATE/home/.kodi
export STATE NIX_CONFIG="experimental-features = nix-command flakes"
[ -z "$LIVE" ] && export DISPLAY=:99

nixbuild() {
  nix build --impure --no-link --print-out-paths -f "$HERE" --arg mock "$([ -n "$LIVE" ] && echo false || echo true)" "$@"
}
tool() {
  nixbuild "tools.$1"
}

setup() {
  # what ../userdata.nix gives barnard's kodi, here as files
  mkdir -p $D/userdata/keymaps $D/userdata/addon_data/plugin.video.themoviedb.helper/players $STATE/shots
  cp $REPO/keyboard.xml $D/userdata/keymaps/keyboard.xml
  cp $REPO/advancedsettings.xml $D/userdata/advancedsettings.xml
  # run.sh xray: the mock's pictures as tmdb's, through images.py
  [ -e $STATE/xray/cert.pem ] && sed -i 's#<pathsubstitution>#&<substitute><from>http://127.0.0.1:8765/img/</from><to>http://127.0.0.1:8770/t/p/</to></substitute>#' $D/userdata/advancedsettings.xml
  cp $REPO/moviepipe-player.json $D/userdata/addon_data/plugin.video.themoviedb.helper/players/moviepipe-download.json
  cat >$D/userdata/addon_data/plugin.video.themoviedb.helper/settings.xml <<EOF
<settings version="2"><setting id="only_resolve_strm">true</setting><setting id="pagemulti_sync">3</setting><setting id="max_threads">10</setting><setting id="artwork_quality">2</setting></settings>
EOF
  # and no network services: kodi under xvfb in a container crashed now and
  # then right as ws-discovery started
  echo '{"settings":{"lookandfeel.skin":"skin.majan","lookandfeel.font":"JetBrains Mono","filelists.showparentdiritems":"false","services.wsdiscovery":"false","services.esenabled":"false","services.zeroconf":"false","services.upnp":"false"},"files":{}}' >$STATE/defaults.json
  python3 $REPO/userdata.py defaults $D $STATE/defaults.json
  python3 $REPO/userdata.py enable $D $(nix eval --impure --raw -f "$HERE" ids --arg mock "$([ -n "$LIVE" ] && echo false || echo true)")
  [ -n "$LIVE" ] && return
  # the mock's: radarr's and sonarr's keys, three channels
  mkdir -p $STATE/keys $D/userdata/addon_data/pvr.iptvsimple
  echo key >$STATE/keys/radarr
  echo key >$STATE/keys/sonarr
  {
    echo '#EXTM3U'
    for n in 1 2 3; do
      echo "#EXTINF:-1 tvg-id=\"c$n\" tvg-logo=\"http://127.0.0.1:8765/img/w500/p400$n.png\",Channel $n"
      echo "http://127.0.0.1:8765/stream/$n"
    done
  } >$STATE/channels.m3u
  printf '<settings version="2"><setting id="kodi_addon_instance_name">Mock</setting><setting id="kodi_addon_instance_enabled">true</setting><setting id="m3uPathType">0</setting><setting id="m3uPath">%s</setting></settings>' \
    $STATE/channels.m3u >$D/userdata/addon_data/pvr.iptvsimple/instance-settings-1.xml
}

start() {
  kodi=$(nixbuild kodi) || exit 1
  mkdir -p $STATE
  if [ -n "$LIVE" ]; then
    setup
    HOME=$STATE/home $kodi/bin/kodi >$STATE/kodi.out 2>&1 &
    return
  fi
  mesa=$(tool mesa) xvfb=$(tool xvfb) magick=$(tool imagemagick)
  pgrep -x Xvfb >/dev/null || {
    LIBGL_DRIVERS_PATH=$mesa/lib/dri LD_LIBRARY_PATH=$mesa/lib $xvfb/bin/Xvfb :99 +extension GLX -screen 0 1920x1080x24 -nolisten tcp >/dev/null 2>&1 &
    sleep 1
  }
  pgrep -f "python3 $HERE/mock.py" >/dev/null || PATH=$magick/bin:$PATH python3 $HERE/mock.py >$STATE/mock.out 2>&1 &
  # the first start makes kodi's databases (and may crash after, under
  # xvfb), the add-ons are turned on in them before the second
  if ! ls $D/userdata/Database/Addons*.db >/dev/null 2>&1; then
    setup
    launch $kodi $mesa
    timeout 60 bash -c "until ls $D/userdata/Database/Addons*.db; do sleep 1; done" >/dev/null 2>&1
    sleep 5
    stop
  fi
  setup
  launch $kodi $mesa
}

launch() {
  # no proxy: the mock is 127.0.0.1. a null audio sink: no sound card. no
  # core file of a crash in the working directory. run.sh xray's
  # image.tmdb.org: its certificate (nixpkgs' openssl reads NIX_SSL_CERT_FILE
  # first, this container has one)
  ulimit -c 0
  cert=$STATE/xray/cert.pem
  [ -e $cert ] || cert=
  env -u HTTPS_PROXY -u HTTP_PROXY -u https_proxy -u http_proxy -u ALL_PROXY -u NO_PROXY -u no_proxy \
    ${cert:+SSL_CERT_FILE=$cert NIX_SSL_CERT_FILE=$cert} HOME=$STATE/home LD_LIBRARY_PATH=$2/lib LIBGL_DRIVERS_PATH=$2/lib/dri \
    __EGL_VENDOR_LIBRARY_DIRS=$2/share/glvnd/egl_vendor.d __GLX_VENDOR_LIBRARY_NAME=mesa LIBGL_ALWAYS_SOFTWARE=1 \
    KODI_AE_SINK=NULL $1/bin/kodi --gl-interface=egl --standalone >$STATE/kodi.out 2>&1 &
}

stop() {
  pkill -x kodi-x11
  pkill -x kodi-wayland
  pkill -x kodi.bin
  sleep 2
}

library() {
  # films for majan's home (its spotlight wants 7.5+, 50+ votes, unwatched):
  # an nfo, a poster and a fanart each, read by "local information only"
  # (metadata.local), no internet. the source's content goes straight into
  # kodi's database (kodi stopped), f scans
  magick=$(tool imagemagick)/bin/magick
  lib=$STATE/library/movies
  n=0
  for title in Sinners Arrival Heat Prisoners Sicario Zodiac Memento Gravity Moon Drive Her Up; do
    n=$((n + 1))
    year=20$((10 + n))
    f="$lib/$title ($year)/$title ($year)"
    [ -e "$f.nfo" ] && continue
    mkdir -p "$(dirname "$f")"
    echo x >"$f.mkv"
    $magick -size 500x750 "xc:hsl($((n * 29 % 360)),55%,35%)" -gravity center -pointsize 72 -fill white -annotate 0 "$title" "$f-poster.png"
    $magick -size 1280x720 "xc:hsl($((n * 29 % 360)),45%,25%)" -gravity center -pointsize 96 -fill white -annotate 0 "$title" "$f-fanart.png"
    printf '%s\n' "<movie><title>$title</title><year>$year</year><runtime>$((90 + n * 5))</runtime>" \
      "<plot>$title, a film of the test library: a plot long enough for three lines of the spotlight and more, so that the fade under its last line shows when the text goes on past what its box holds.</plot>" \
      "<ratings><rating name=\"themoviedb\" max=\"10\" default=\"true\"><value>8.$n</value><votes>$((100 * n))</votes></rating></ratings>" \
      "<uniqueid type=\"tmdb\" default=\"true\">$((1000 + n))</uniqueid><genre>Drama</genre><director>Denis Villeneuve</director></movie>" >"$f.nfo"
  done
  python3 -c '
import glob, sqlite3, sys
db = max(glob.glob(sys.argv[1] + "/MyVideos*.db"))
with sqlite3.connect(db) as c:
    if not c.execute("select 1 from path where strPath = ?", (sys.argv[2],)).fetchone():
        c.execute("insert into path (strPath, strContent, strScraper, scanRecursive, useFolderNames, strSettings, noUpdate, exclude, allAudio) values (?, \"movies\", \"metadata.local\", 2147483647, 0, \"\", 0, 0, 0)", (sys.argv[2],))
' "$D/userdata/Database" "$lib/"
  printf '<sources><video><default pathversion="1"></default><source><name>Movies</name><path pathversion="1">%s/</path><allowsharing>true</allowsharing></source></video></sources>\n' "$lib" >$D/userdata/sources.xml
}

case "${1:-}" in
start) start ;;
library) library ;;
xray)
  pkill -f "python3 $HERE/xray.py"
  PATH=$(tool openssl)/bin:$PATH python3 $HERE/xray.py "${2:-8}" >$STATE/xray.out 2>&1 &
  timeout 20 bash -c "until grep -q up $STATE/xray.out; do sleep 0.2; done"
  ;;
stop) stop ;;
shot) $(tool imagemagick)/bin/import -window root "$STATE/shots/$2.png" ;;
key)
  shift
  xdo=$(tool xdotool)/bin/xdotool
  for k in "$@"; do
    $xdo key --delay 50 "$k"
    sleep 0.6
  done
  ;;
type) $(tool xdotool)/bin/xdotool type --delay 80 "$2" ;;
log) tail -n "${2:-40}" $D/temp/kodi.log ;;
errs)
  grep -E " (error|warning) " $D/temp/kodi.log |
    grep -vE "ActiveAE|OpenSink|Avahi|Zeroconf|DBus|Error getting /nix|xbmcbin|LogindUPower|GL_EXT|Skipped .* duplicate|vaGetDriver|sleep delay|plugin.video.youtube" |
    cut -c1-260 | tail -n "${2:-30}"
  ;;
*) sed -n '2,16p' "$0" ;;
esac
