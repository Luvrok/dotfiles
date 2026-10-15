# Теги всех мониторов для eww (deflisten). У каждого монитора свои 1..9:
# основной — воркспейсы 1..9, следующие слева направо — 11..19, 21..29 (см. i3-ws).
# Печатает одну строку JSON на каждое изменение в i3:
#   [{"output":"DisplayPort-1","num":1,"label":"1","focused":true,"visible":true,
#     "urgent":false,"occupied":true}, ...]
# output   — монитор, в чьём баре показывать тег.
# visible  — тег открыт на этом мониторе, focused — и монитор в фокусе.
# occupied — на воркспейсе есть хотя бы одно окно (как квадратик у тега в dwm).
# Чужие воркспейсы, оказавшиеся на мониторе (второй монитор отключили),
# идут после тегов с меткой-номером, чтобы их окна не терялись.

# i3 при рестарте создаёт новый сокет, а I3SOCK в окружении остаётся старым.
# Без него i3-msg каждый раз находит актуальный сокет через свойство X.
unset I3SOCK

last='[]'

# Печатает состояние; если i3 не ответил — повторяет последнее известное.
# Печать нужна в любом случае: когда eww закрыт, запись в закрытый канал
# завершает скрипт, и он не остаётся висеть сиротой.
emit() {
  local ws tree outs out
  if ws=$(i3-msg -t get_workspaces) &&
    tree=$(i3-msg -t get_tree) &&
    outs=$(i3-msg -t get_outputs) &&
    out=$(jq -cn --argjson ws "$ws" --argjson tree "$tree" --argjson outs "$outs" '
      ( [ $tree | .. | objects | select(.type? == "workspace")
          | { key: .name, value: ([ .. | objects | select(.window? != null) ] | length) } ]
        | from_entries ) as $count
      | [ [ $outs[] | select(.active) ] | sort_by([(.primary | not), .rect.x]) | to_entries[]
          | (.key * 10) as $off
          | .value.name as $o
          | ( [ range(1; 10) | { num: ($off + .), label: tostring } ]
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

# Слушатель не должен умирать от одной неудачной команды i3-msg или jq.
set +o errexit

while true; do
  emit
  # События окон title/focus/mark на теги не влияют — их пропускаем,
  # чтобы не дёргать i3 на каждую смену вкладки в браузере.
  # События воркспейсов (включая focus) и мониторов обрабатываем все.
  i3-msg -t subscribe -m '["workspace","window","output"]' | while read -r event; do
    case "$(jq -r 'if has("container") then "window-" + .change else "other" end' <<<"$event")" in
      window-title | window-focus | window-mark) ;;
      *) emit ;;
    esac
  done
  # Подписка оборвалась (i3 перезапускался) — ждём и подписываемся заново
  sleep 1
done
