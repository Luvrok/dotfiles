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
  cp $REPO/moviepipe-player.json $D/userdata/addon_data/plugin.video.themoviedb.helper/players/moviepipe-download.json
  cat >$D/userdata/addon_data/plugin.video.themoviedb.helper/settings.xml <<EOF
<settings version="2"><setting id="only_resolve_strm">true</setting><setting id="pagemulti_sync">3</setting></settings>
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
  # core file of a crash in the working directory
  ulimit -c 0
  env -u HTTPS_PROXY -u HTTP_PROXY -u https_proxy -u http_proxy -u ALL_PROXY -u NO_PROXY -u no_proxy \
    HOME=$STATE/home LD_LIBRARY_PATH=$2/lib LIBGL_DRIVERS_PATH=$2/lib/dri \
    __EGL_VENDOR_LIBRARY_DIRS=$2/share/glvnd/egl_vendor.d __GLX_VENDOR_LIBRARY_NAME=mesa LIBGL_ALWAYS_SOFTWARE=1 \
    KODI_AE_SINK=NULL $1/bin/kodi --gl-interface=egl --standalone >$STATE/kodi.out 2>&1 &
}

stop() {
  pkill -x kodi-x11
  pkill -x kodi-wayland
  pkill -x kodi.bin
  sleep 2
}

case "${1:-}" in
start) start ;;
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
*) sed -n '2,11p' "$0" ;;
esac
