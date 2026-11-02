# Уровень Wi-Fi для бара (иконка по RSSI).
# Если интерфейса нет (десктоп без Wi-Fi) — пусто, блок в баре скрывается.

INTERFACE="wlan0"

if [ ! -e "/sys/class/net/$INTERFACE" ]; then
  exit 0
fi

WIFI_INFO=$(iwctl station "$INTERFACE" show 2>/dev/null || true)
RAW_RSSI=$(printf '%s\n' "$WIFI_INFO" | awk '/RSSI/ && !/Average/ { print $2; exit }')

case "$RAW_RSSI" in
  '' | *[!0-9-]*)
    {
      echo "------ $(date '+%F %T') -----"
      echo "iface: $INTERFACE"
      echo "raw_rssi: ${RAW_RSSI:-<empty>}"
      echo
      echo "[iwctl station show]"
      iwctl station "$INTERFACE" show 2>&1 || true
      echo
      echo "[iw dev link]"
      iw dev "$INTERFACE" link 2>&1 || true
      echo
      echo "[ip link]"
      ip link show "$INTERFACE" 2>&1 || true
      echo
    } >>"$HOME/.wifi_debug.log"

    printf '%s\n' "󰤫"
    exit 0
    ;;
esac

RSSI=$RAW_RSSI

if [ "$RSSI" -ge -50 ]; then
  ICON="󰤨"
elif [ "$RSSI" -ge -60 ]; then
  ICON="󰤥"
elif [ "$RSSI" -ge -70 ]; then
  ICON="󰤢"
elif [ "$RSSI" -ge -80 ]; then
  ICON="󰤟"
else
  ICON="󰤫"
fi

printf '%s\n' "$ICON"
