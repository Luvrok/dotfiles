# Индикатор записи экрана для бара: пусто, если запись не идёт.

PIDFILE="/tmp/recpid"

if [ -f "$PIDFILE" ]; then
  pid=$(cat "$PIDFILE" 2>/dev/null || true)
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    printf '%s\n' ' rec '
  fi
fi
