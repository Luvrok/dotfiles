#!/usr/bin/env bash
# keyboard-first wifi menu on iwd: eww draws, i3 binding mode feeds keys
set -euo pipefail

dev="${WIFI_DEV:-wlan0}"
state="${XDG_RUNTIME_DIR:-/tmp}/wifi-menu"
list="$state/list.json"
selfile="$state/sel"
pending="$state/pending"
openflag="$state/open"
watchpid="$state/watch.pid"
max=10 # visible rows
mkdir -p "$state"

notify() { notify-send -a wifi "$@" 2>/dev/null || true; }

objects() {
  busctl --json=short call net.connman.iwd / org.freedesktop.DBus.ObjectManager GetManagedObjects
}

# dbus path of the station for $dev
station_of() {
  jq -r --arg d "$dev" '.data[0] | to_entries[]
    | select(.value["net.connman.iwd.Station"]
             and .value["net.connman.iwd.Device"].Name.data == $d)
    | .key' | head -n1
}

station() { objects | station_of; }

scan() {
  local objs st ordered
  objs=$(objects)
  st=$(station_of <<<"$objs")
  if [[ -z "$st" ]]; then
    echo '[]' >"$list"
    return
  fi
  ordered=$(busctl --json=short call net.connman.iwd "$st" net.connman.iwd.Station GetOrderedNetworks)
  # signal is dBm * 100, iwd already sorts by it
  jq -n --argjson objs "$objs" --argjson ord "$ordered" '
    $objs.data[0] as $o
    | $ord.data[0]
    | map(. as [$path, $sig]
        | $o[$path]["net.connman.iwd.Network"] as $n
        | select($n != null)
        | {
            ssid: $n.Name.data,
            type: $n.Type.data,
            connected: ($n.Connected.data // false),
            known: ($n.KnownNetwork != null),
            signal: $sig
          })
    | sort_by(.connected | not)
    | map(. + {
        inuse: (if .connected then "*" else "" end),
        locked: (.type != "open"),
        bars: (if .signal >= -6000 then "▮▮▮▮"
               elif .signal >= -6700 then "▮▮▮▯"
               elif .signal >= -7500 then "▮▮▯▯"
               else "▮▯▯▯" end)
      })' >"$list.tmp"
  mv "$list.tmp" "$list"
}

render() {
  local n sel off view
  n=$(jq length "$list")
  sel=$(cat "$selfile" 2>/dev/null || echo 0)
  ((sel >= n)) && sel=$((n - 1))
  ((sel < 0)) && sel=0
  echo "$sel" >"$selfile"
  # scroll so the cursor stays visible
  off=$((sel < max ? 0 : sel - max + 1))
  view=$(jq -c --argjson s "$sel" --argjson o "$off" --argjson m "$max" \
    'to_entries | .[$o:$o+$m] | to_entries
     | map(.value.value + {sel: (.value.key == $s), i: .key})' "$list")
  if ((n == 0)); then
    eww update wifi_view='[]' wifi_status="no networks"
  else
    eww update wifi_view="$view" wifi_status="$((sel + 1))/$n"
  fi
}

# rescan the list but keep the cursor on the same network
refresh() {
  local cur="" idx=""
  if [[ -f "$list" ]]; then
    cur=$(jq -r --argjson s "$(cat "$selfile" 2>/dev/null || echo 0)" '.[$s].ssid // empty' "$list")
  fi
  scan
  if [[ -n "$cur" ]]; then
    idx=$(jq --arg c "$cur" 'map(.ssid) | index($c) // empty' "$list")
    [[ -n "$idx" ]] && echo "$idx" >"$selfile"
  fi
  render
}

# fresh scan, list updates live while it runs
watch() {
  local st
  st=$(station)
  [[ -z "$st" ]] && return
  eww update wifi_scanning=true
  # fails with busy if iwd is already scanning, that's fine
  busctl call net.connman.iwd "$st" net.connman.iwd.Station Scan >/dev/null 2>&1 || true
  for _ in {1..20}; do # max 10s
    sleep 0.5
    [[ -f "$openflag" ]] || return
    refresh
    [[ "$(busctl get-property net.connman.iwd "$st" net.connman.iwd.Station Scanning)" == "b false" ]] && break
  done
  eww update wifi_scanning=false
}

start_watch() {
  stop_watch
  watch </dev/null >/dev/null 2>&1 &
  echo $! >"$watchpid"
}

stop_watch() {
  if [[ -f "$watchpid" ]]; then
    kill "$(cat "$watchpid")" 2>/dev/null || true
    rm -f "$watchpid"
  fi
}

move() {
  local sel
  sel=$(cat "$selfile" 2>/dev/null || echo 0)
  echo $((sel + $1)) >"$selfile"
  render
}

hide() {
  rm -f "$openflag"
  stop_watch
  eww update wifi_reveal=false wifi_scanning=false wifi_rows=false
  sleep 0.25 # let the revealer finish
  eww close wifi-menu 2>/dev/null || true
}

open() {
  echo 0 >"$selfile"
  touch "$openflag"
  eww update wifi_view='[]' wifi_status="" wifi_rows=false
  eww open wifi-menu
  eww update wifi_reveal=true
  # cached list right away, rows cascade in, then the scan fills it in
  refresh
  eww update wifi_rows=true
  start_watch
}

select_item() {
  local sel item ssid connected known locked
  sel=$(cat "$selfile" 2>/dev/null || echo 0)
  item=$(jq -c --argjson s "$sel" '.[$s] // empty' "$list")
  [[ -z "$item" ]] && return
  ssid=$(jq -r .ssid <<<"$item")
  connected=$(jq -r .connected <<<"$item")
  known=$(jq -r .known <<<"$item")
  locked=$(jq -r .locked <<<"$item")

  i3-msg -q mode default
  hide

  if [[ "$connected" == true ]]; then
    # enter on the current network disconnects
    if iwctl station "$dev" disconnect; then notify "disconnected" "$ssid"; else notify "failed to disconnect" "$ssid"; fi
  elif [[ "$known" == true || "$locked" == false ]]; then
    notify "connecting" "$ssid"
    if iwctl station "$dev" connect "$ssid" </dev/null >/dev/null 2>&1; then notify "connected" "$ssid"; else notify "failed" "$ssid"; fi
  else
    # unknown secured network, ask for a password
    echo "$ssid" >"$pending"
    eww update wifi_ssid="$ssid"
    eww open wifi-pass
    i3-msg -q mode wifi-pass
  fi
}

pass() {
  local ssid
  ssid=$(cat "$pending")
  rm -f "$pending"
  eww close wifi-pass 2>/dev/null || true
  i3-msg -q mode default
  [[ -z "$1" ]] && { notify "cancelled" "$ssid"; return; }
  notify "connecting" "$ssid"
  if iwctl --passphrase "$1" station "$dev" connect "$ssid" </dev/null >/dev/null 2>&1; then notify "connected" "$ssid"; else notify "failed" "$ssid"; fi
}

cancel() {
  rm -f "$pending"
  eww close wifi-pass 2>/dev/null || true
  hide
}

case "${1:-}" in
  open) open ;;
  close) hide ;;
  up) move -1 ;;
  down) move 1 ;;
  top) echo 0 >"$selfile" && render ;;
  bottom) echo 9999 >"$selfile" && render ;;
  rescan) start_watch ;;
  select) select_item ;;
  pass) pass "${2:-}" ;;
  cancel) cancel ;;
  *) echo "usage: wifi-menu open|close|up|down|top|bottom|rescan|select|pass <pw>|cancel" >&2; exit 1 ;;
esac
