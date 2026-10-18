# tags of all monitors for eww (deflisten). every monitor has its own 1..9:
# primary is workspaces 1..9, the next ones left to right 11..19, 21..29 (see i3-ws).
# one json line per i3 change:
#   [{"output":"DisplayPort-1","num":1,"label":"a","focused":true,"visible":true,
#     "urgent":false,"occupied":true}, ...]
# output: the monitor whose bar shows the tag
# visible: tag is open on that monitor, focused: and the monitor has focus
# occupied: the workspace has at least one window (dwm's tag square)
# foreign workspaces that ended up here (second monitor unplugged) come after
# the tags, labeled with their name, so their windows don't get lost

# tag labels for 1..9, space separated, missing ones fall back to the number
LABELS='"scl", "obs", "sh1", "sh2", "smth", "virt", "med", "smth", "vpn"'

# i3 makes a new socket on restart, the env still has the old one
unset I3SOCK

last='[]'

# print the state, the last one if i3 didn't answer. always print: once eww
# is gone the write fails and the script exits instead of hanging around
emit() {
  local ws tree outs out
  if ws=$(i3-msg -t get_workspaces) &&
    tree=$(i3-msg -t get_tree) &&
    outs=$(i3-msg -t get_outputs) &&
    out=$(jq -cn --argjson ws "$ws" --argjson tree "$tree" --argjson outs "$outs" \
      --argjson labels "[$LABELS]" '
      $labels as $l
      | ( [ $tree | .. | objects | select(.type? == "workspace")
          | { key: .name, value: ([ .. | objects | select(.window? != null) ] | length) } ]
        | from_entries ) as $count
      | [ [ $outs[] | select(.active) ] | sort_by([(.primary | not), .rect.x]) | to_entries[]
          | (.key * 10) as $off
          | .value.name as $o
          | ( [ range(1; 10) | { num: ($off + .), label: ($l[. - 1] // tostring) } ]
              + [ $ws[] | select(.output == $o and (.num <= $off or .num > $off + 9))
                  | { num, label: .name } ] )[]
          | .num as $n
          | ($ws | map(select(.num == $n and .output == $o)) | first) as $w
          | { output: $o, num, label,
              focused:  ($w.focused // false),
              visible:  ($w.visible // false),
              urgent:   ($w.urgent // false),
              occupied: (($count[$w.name // ""] // 0) > 0) } ]'); then
    last=$out
  fi
  printf '%s\n' "$last"
}

# one failed i3-msg or jq must not kill the listener
set +o errexit

while true; do
  emit
  # window title/focus/mark events don't change tags, skip them so a browser
  # tab switch doesn't poke i3. all workspace (focus too) and output events count
  i3-msg -t subscribe -m '["workspace","window","output"]' | while read -r event; do
    case "$(jq -r 'if has("container") then "window-" + .change else "other" end' <<<"$event")" in
      window-title | window-focus | window-mark) ;;
      *) emit ;;
    esac
  done
  # subscription dropped (i3 restarted), wait and subscribe again
  sleep 1
done
