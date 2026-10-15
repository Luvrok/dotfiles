# Поднимает демон eww и открывает бар на каждом активном мониторе.
#   eww-launch         — (пере)открыть бар на всех мониторах
#   eww-launch toggle  — спрятать бар, если открыт, иначе открыть

if ! eww ping >/dev/null 2>&1; then
  eww daemon
  for _ in $(seq 50); do
    eww ping >/dev/null 2>&1 && break
    sleep 0.1
  done
fi

if [ "${1:-}" = toggle ] && [ -n "$(eww active-windows)" ]; then
  eww close-all
  exit 0
fi

eww close-all

windows=()
args=()
while read -r monitor; do
  windows+=("bar:bar-$monitor")
  args+=(--arg "bar-$monitor:monitor=$monitor")
done < <(xrandr --listactivemonitors | awk 'NR > 1 { print $NF }')

eww open-many "${windows[@]}" "${args[@]}"
