# Громкость для бара.
#   db-volume            — вывести статус
#   db-volume up | down  — ±2% (если звук не выключен)
#   db-volume mute       — выключить/включить звук
# В dwmblocks действие приходит через BLOCK_BUTTON (4/5 — колесо, 2 — средняя кнопка).

SINK='@DEFAULT_AUDIO_SINK@'
STEP=2

# Обновить блок в баре сразу: eww в i3, dwmblocks в dwm (что не запущено — молча пропустится)
refresh() {
  eww poll volume >/dev/null 2>&1 || true
  pkill -RTMIN+4 dwmblocks 2>/dev/null || true
}

getvol() {
  wpctl get-volume "$SINK" | awk '{ print int($2 * 100 + 0.5) }'
}

ismuted() {
  [[ $(wpctl get-volume "$SINK") == *MUTED* ]]
}

action="${1:-}"
case "${BLOCK_BUTTON:-}" in
  4) action=up ;;
  5) action=down ;;
  2) action=mute ;;
esac

case "$action" in
  up | down)
    if ! ismuted; then
      v=$(getvol)
      if [ "$action" = up ]; then v=$((v + STEP)); else v=$((v - STEP)); fi
      if [ "$v" -gt 100 ]; then v=100; fi
      if [ "$v" -lt 0 ]; then v=0; fi
      wpctl set-volume "$SINK" "$v%"
    fi
    ;;
  mute)
    wpctl set-mute "$SINK" toggle
    ;;
esac

if [ -n "$action" ]; then
  refresh
fi

if ismuted; then
  echo ""
  exit 0
fi

v=$(getvol)
if [ "$v" -gt 40 ]; then
  icon=""
elif [ "$v" -gt 15 ]; then
  icon=""
else
  icon=""
fi

echo "$icon $v%"
