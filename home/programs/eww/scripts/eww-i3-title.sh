# Заголовок окна в фокусе и монитор, на котором оно, для eww (deflisten).
# Печатает строку JSON: {"title":"...","output":"DisplayPort-1"}
# На пустом воркспейсе title пустой — как в dwm.

# i3 при рестарте создаёт новый сокет, а I3SOCK в окружении остаётся старым.
# Без него i3-msg каждый раз находит актуальный сокет через свойство X.
unset I3SOCK

last='{"title":"","output":""}'

# Печатает состояние; если i3 не ответил — повторяет последнее известное.
# Печать нужна в любом случае: когда eww закрыт, запись в закрытый канал
# завершает скрипт, и он не остаётся висеть сиротой.
emit() {
  local tree output out
  if tree=$(i3-msg -t get_tree) &&
    output=$(i3-msg -t get_workspaces | jq -r '.[] | select(.focused) | .output') &&
    out=$(jq -cn --argjson tree "$tree" --arg output "$output" '
      { title: ([ $tree | .. | objects | select(.focused? == true and .window? != null) | .name ] | first // ""),
        output: $output }'); then
    last=$out
  fi
  printf '%s\n' "$last"
}

# Слушатель не должен умирать от одной неудачной команды i3-msg или jq.
set +o errexit

while true; do
  emit
  i3-msg -t subscribe -m '["window","workspace"]' | while read -r event; do
    case "$(jq -r '.change // ""' <<<"$event")" in
      focus | title | close | new | move | empty | init) emit ;;
    esac
  done
  # Подписка оборвалась (i3 перезапускался) — ждём и подписываемся заново
  sleep 1
done
