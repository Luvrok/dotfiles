PIDFILE="/tmp/recpid"

status() {
  # Пока идёт запись, перед [EN]/[RU] нет пробела: его даёт блок rec
  local prefix=" "
  if [ -f "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    prefix=""
  fi

  case "$(xkb-switch -p)" in
    ru*) printf '%s[RU]\n' "$prefix" ;;
    *) printf '%s[EN]\n' "$prefix" ;;
  esac
}

action="${1:-}"
if [ "${BLOCK_BUTTON:-}" = 1 ]; then action=toggle; fi

case "$action" in
  toggle)
    xkb-switch -n
    # В i3 бар обновит `i3-xkb listen`, в dwm — сигнал dwmblocks
    pkill -RTMIN+1 dwmblocks 2>/dev/null || true
    status
    ;;
  listen)
    # Слушатель не должен умирать от одной неудачной команды
    set +o errexit
    while true; do
      status
      xkb-switch -W | while read -r _; do status; done
      # xkb-switch завершился (X перезапускался) — ждём и слушаем заново
      sleep 1
    done
    ;;
  *)
    status
    ;;
esac

