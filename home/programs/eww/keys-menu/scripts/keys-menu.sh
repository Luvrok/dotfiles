# keybind cheat sheet: pages from keys.conf, eww draws, i3 mode "keys" feeds
# its own keys. any other key or any click closes it
#   keys-menu toggle        open on the page of the focused app, or close
#   keys-menu next | prev   flip pages
#   keys-menu close

conf=${XDG_CONFIG_HOME:-$HOME/.config}/eww/keys-menu/keys.conf
state=${XDG_RUNTIME_DIR:-/tmp}/keys-menu
pages=$state/pages.json
page=$state/page
watch_pid=$state/watch.pid
closed=$state/closed
mkdir -p "$state"

# keys that mode "keys" binds in i3-keys.conf, they don't close the menu
menu_keys="h l Left Right Tab Escape q"

# i3 makes a new socket on restart, the env still has the old one
unset I3SOCK

# keys.conf -> [{name, classes, cols: [[{name, i, rows: [{keys, what}]}]]}]
parse() {
  jq -R -s '
    def keycaps:
      [split(" / ")[] | [splits("\\+(?=.)") | {t: ., c: (if IN("mod", "shift", "ctrl", "alt") then "mod" else "key" end)}]]
      | [.[] | ., [{t: "/", c: "sep"}]] | .[:-1] | add;

    reduce (split("\n")[] | sub("^\\s+"; "") | sub("\\s+$"; "") | select(. != "" and (startswith("#") | not))) as $l
      ([];
       if $l | test("^\\[.*\\]$") then
         ($l | ltrimstr("[") | rtrimstr("]") | [splits("\\s+")]) as $w
         | . + [{name: $w[0], classes: ($w | map(ascii_downcase)), secs: []}]
       else
         # a row or a section before any page or section still goes somewhere
         (if length == 0 then [{name: "keys", classes: [], secs: []}] else . end)
         | if $l | test("\\S(\\s{2,}|\\t)\\S") then
             ($l | capture("^(?<k>.*?\\S)(\\s{2,}|\\t)\\s*(?<w>.*)$")) as $m
             | (if (.[-1].secs | length) == 0 then .[-1].secs += [{name: "", rows: []}] else . end)
             | .[-1].secs[-1].rows += [{keys: ($m.k | keycaps), what: $m.w}]
           elif $l | endswith(":") then
             .[-1].secs += [{name: ($l | rtrimstr(":")), rows: []}]
           else . end
       end)
    # two columns for a long page, a title counts as 1.5 rows
    | map(. as $p
      | ($p.secs | map(1.5 + (.rows | length)) | add // 0) as $total
      | $p + {cols: (reduce ($p.secs | to_entries[]) as $e ({cols: [[]], w: 0};
          (1.5 + ($e.value.rows | length)) as $sw
          | if $total > 32 and (.cols | length) < 2 and .w > 0 and .w + $sw / 2 > $total / 2
            then .cols += [[]] | .w = 0 else . end
          | .cols[-1] += [$e.value + {i: (.cols[-1] | length)}]
          | .w += $sw) | .cols)}
      | del(.secs))
  ' "$conf" >"$pages"
}

# page $1 to eww, its sections cascade in like the wifi rows
show() {
  echo "$1" >"$page"
  eww update keys_rows=false
  eww update keys_page="$(jq -c --argjson p "$1" '
    {cols: .[$p].cols, tabs: (to_entries | map({name: .value.name, sel: (.key == $p)}))}' "$pages")"
  eww update keys_rows=true
}

flip() {
  local n
  n=$(jq length "$pages")
  show $((($(cat "$page") + $1 + n) % n))
}

# first key or click that isn't ours closes the menu, it still does its thing
watch() {
  local keep fd xi
  keep=" $(xmodmap -pke | awk -v k=" $menu_keys " 'index(k, " " $4 " ") { printf "%s ", $2 }')"
  exec {fd}< <(exec xinput test-xi2 --root)
  xi=$!
  awk -v keep="$keep" '
    /^EVENT/ { ev = $NF; next }
    ev == "(RawButtonPress)" && $1 == "detail:" { exit }
    ev == "(RawKeyPress)" && $1 == "detail:" && !index(keep, " " $2 " ") { exit }
  ' <&"$fd" || true
  kill "$xi" 2>/dev/null || true
  rm -f "$watch_pid"
  hide
}

hide() {
  date +%s%6N >"$closed"
  i3-msg -q mode default || true
  eww update keys_rows=false keys_reveal=false
  sleep 0.2 # let the revealer finish
  eww close keys-menu 2>/dev/null || true
}

# the watcher runs in its own process group, this takes down xinput too
stop_watch() {
  if [[ -f $watch_pid ]]; then
    kill -- -"$(cat "$watch_pid")" 2>/dev/null || true
    rm -f "$watch_pid"
  fi
}

open() {
  local out cls start
  stop_watch
  parse
  out=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused) | .output')
  cls=$(i3-msg -t get_tree | jq -r 'first(.. | objects | select(.focused == true) | .window_properties.class // empty) // ""')
  start=$(jq --arg c "${cls,,}" '(map(.classes | index($c) != null) | index(true)) // 0' "$pages")
  eww update keys_reveal=false keys_rows=false
  eww open keys-menu --screen "$out"
  eww update keys_reveal=true
  show "$start"
  i3-msg -q mode keys
  set -m
  watch </dev/null >/dev/null 2>&1 &
  set +m
  echo $! >"$watch_pid"
}

close() {
  stop_watch
  hide
}

case ${1:-} in
  toggle)
    if [[ $(eww active-windows) == *keys-menu* ]]; then
      close
    # mod went down first and already closed it, so the / of mod+/ is late
    elif (($(date +%s%6N) - $(cat "$closed" 2>/dev/null || echo 0) > 400000)); then
      open
    fi
    ;;
  next) flip 1 ;;
  prev) flip -1 ;;
  close) close ;;
  json) parse && jq . "$pages" ;;
  *)
    echo "usage: keys-menu toggle | next | prev | close | json" >&2
    exit 1
    ;;
esac
