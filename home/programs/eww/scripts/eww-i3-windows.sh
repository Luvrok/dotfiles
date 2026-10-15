# Окна для eww (deflisten), как awesomebar в dwm: на каждом мониторе — все окна
# открытого на нём тега и символ раскладки.
# Печатает одну строку JSON на каждое изменение в i3:
#   [{"kind":"layout","output":"DisplayPort-1","text":"[2]"},
#    {"kind":"win","output":"DisplayPort-1","id":94213,"title":"nvim","selected":true}, ...]
# Список плоский: бар каждого монитора берёт свои элементы по output.
# selected — окно, последнее в фокусе на этом мониторе. Как m->sel в dwm,
# оно подсвечено на обоих мониторах, а не только на том, где фокус.
# Раскладка как ltsymbol в dwm: 󰓒 — тайлинг, [n] — tabbed/stacked (monocle)
# на n вкладок,  — tabbed на пустом теге.

# i3 при рестарте создаёт новый сокет, а I3SOCK в окружении остаётся старым.
# Без него i3-msg каждый раз находит актуальный сокет через свойство X.
unset I3SOCK

last='[]'

# Печатает состояние; если i3 не ответил — повторяет последнее известное.
# Печать нужна в любом случае: когда eww закрыт, запись в закрытый канал
# завершает скрипт, и он не остаётся висеть сиротой.
emit() {
  local tree out
  if tree=$(i3-msg -t get_tree) && out=$(jq -c '
    # Окно, последнее в фокусе внутри контейнера (тайлинговое или плавающее)
    def sel:
      if .window != null then .id
      else ([ .focus[] as $f | (.nodes[], .floating_nodes[]) | select(.id == $f) ] | first) as $c
        | if $c == null then null else $c | sel end
      end;
    # Верхний tabbed/stacked контейнер на пути к тайлинговому окну в фокусе
    # (сплит внутри вкладки не отменяет monocle)
    def tabbed:
      if .layout == "tabbed" or .layout == "stacked" then .
      else ([ .focus[] as $f | .nodes[] | select(.id == $f) ] | first) as $c
        | if $c == null then empty else $c | tabbed end
      end;
    # Окна по порядку: сначала тайлинговые, потом плавающие
    def windows:
      if .window != null then . else (.nodes[], .floating_nodes[]) | windows end;

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

# Слушатель не должен умирать от одной неудачной команды i3-msg или jq.
set +o errexit

while true; do
  emit
  # Нужны все события окон, включая смену заголовка. binding — потому что
  # смена раскладки (mod+t / mod+m) своего события в i3 не даёт.
  i3-msg -t subscribe -m '["window","workspace","output","binding"]' | while read -r _; do
    emit
  done
  # Подписка оборвалась (i3 перезапускался) — ждём и подписываемся заново
  sleep 1
done
