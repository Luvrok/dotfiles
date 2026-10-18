# windows for eww (deflisten), like dwm's awesomebar: every monitor gets the
# windows of its open tag and a layout symbol. one json line per i3 change:
#   [{"kind":"layout","output":"DisplayPort-1","text":"[2]"},
#    {"kind":"win","output":"DisplayPort-1","id":94213,"title":"nvim","selected":true}, ...]
# flat list, each bar picks its own by output. selected is the last focused
# window of that monitor (dwm's m->sel), lit on both monitors.
# layout like dwm's ltsymbol: 󰓒 tiling, [n] tabbed/stacked with n tabs,
# empty for tabbed on an empty tag.

# i3 makes a new socket on restart, the env still has the old one
unset I3SOCK

last='[]'

# print the state, the last one if i3 didn't answer. always print: once eww
# is gone the write fails and the script exits instead of hanging around
emit() {
  local tree out
  if tree=$(i3-msg -t get_tree) && out=$(jq -c '
    # last focused window inside a con, tiled or floating
    def sel:
      if .window != null then .id
      else ([ .focus[] as $f | (.nodes[], .floating_nodes[]) | select(.id == $f) ] | first) as $c
        | if $c == null then null else $c | sel end
      end;
    # top tabbed/stacked con on the way to the focused tile
    # (a split inside a tab is still monocle)
    def tabbed:
      if .layout == "tabbed" or .layout == "stacked" then .
      else ([ .focus[] as $f | .nodes[] | select(.id == $f) ] | first) as $c
        | if $c == null then empty else $c | tabbed end
      end;
    # tiled first, then floating, without the flameshot overlay
    def windows:
      if .window != null then select(.window_properties.class // "" | test("^flameshot$") | not)
      else (.nodes[], .floating_nodes[]) | windows end;

    [ .nodes[] | select(.type == "output" and .name != "__i3") | .name as $o
      | .nodes[] | select(.type == "con")
      | .focus[0] as $vis
      | .nodes[] | select(.id == $vis)
      | sel as $sel
      | ( [ tabbed ] | first
          | if . == null then "󰓒"
            elif (.nodes | length) > 0 then "[\(.nodes | length)]"
            else "" end ) as $lt
      | { kind: "layout", output: $o, text: $lt },
        ( windows | { kind: "win", output: $o, id, title: (.name // ""), selected: (.id == $sel) } ) ]
  ' <<<"$tree"); then
    last=$out
  fi
  printf '%s\n' "$last"
}

# one failed i3-msg or jq must not kill the listener
set +o errexit

while true; do
  emit
  # all window events, titles too. binding: mod+t / mod+m send no layout event
  i3-msg -t subscribe -m '["window","workspace","output","binding"]' | while read -r _; do
    emit
  done
  # subscription dropped (i3 restarted), wait and subscribe again
  sleep 1
done
