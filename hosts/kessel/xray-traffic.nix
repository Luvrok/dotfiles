{
  config,
  lib,
  pkgs,
  ...
}:

let
  dir = "/var/lib/xray-traffic";

  # xray keeps counters, not history: the sampler asks with reset=true, so
  # every run returns "what happened since the previous run" and appends it
  # to a monthly tsv. missing a run loses that slice, nothing else
  sampler = pkgs.writeShellApplication {
    name = "xray-traffic-sample";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.jq
      pkgs.xray
    ];
    text = ''
      set -euo pipefail
      dir=${dir}
      install -d -m 0755 "$dir"

      stats=$(xray api statsquery --server=127.0.0.1:10085 -pattern 'user>>>' -reset=true 2>/dev/null) || exit 0
      [ -n "$stats" ] || exit 0

      ts=$(date '+%Y-%m-%d %H:%M')
      month=$(date +%Y-%m)

      printf '%s' "$stats" | jq -r --arg ts "$ts" '
        [ .stat[]? | select(.name | startswith("user>>>")) | { name: .name, value: (.value | tonumber) } ]
        | map(. + { email: (.name | split(">>>")[1]), kind: (.name | split(">>>")[3]) })
        | group_by(.email)
        | .[]
        | {
            email: .[0].email,
            up: ([ .[] | select(.kind == "uplink") | .value ] | add // 0),
            down: ([ .[] | select(.kind == "downlink") | .value ] | add // 0)
          }
        | select(.email != null and (.up > 0 or .down > 0))
        | "\($ts)\t\(.email)\t\(.up)\t\(.down)"
      ' >> "$dir/$month.tsv"

      find "$dir" -maxdepth 1 -name '*.tsv' -mtime +400 -delete
    '';
  };

  cli = pkgs.writeShellApplication {
    name = "xray-traffic";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gawk
    ];
    text = ''
      set -euo pipefail
      dir=''${XRAY_TRAFFIC_DIR:-${dir}}
      mode=today
      days=7
      months=6
      who=""

      usage() {
        cat <<'EOF'
      usage: xray-traffic [-d [n]] [-m [n]] [-u email]

        (no option)  today, one row per user
        -d [n]       last n days (7 by default), one row per day
        -m [n]       last n months (6 by default), one row per month
        -u email     only that user, works with every mode
      EOF
      }

      while [ $# -gt 0 ]; do
        case "$1" in
          -d)
            mode=day
            shift
            if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
              days=$1
              shift
            fi
            ;;
          -m)
            mode=month
            shift
            if [ $# -gt 0 ] && [[ "$1" =~ ^[0-9]+$ ]]; then
              months=$1
              shift
            fi
            ;;
          -u)
            if [ $# -lt 2 ]; then
              usage
              exit 2
            fi
            who=$2
            shift 2
            ;;
          -h|--help)
            usage
            exit 0
            ;;
          *)
            usage
            exit 2
            ;;
        esac
      done

      if [ -z "$(find "$dir" -maxdepth 1 -name '*.tsv' -print -quit 2>/dev/null)" ]; then
        echo "no samples yet: the sampler runs every 5 minutes" >&2
        exit 0
      fi

      today=$(date +%F)
      case "$mode" in
        today)
          cutoff=$today
          label=user
          title="today"
          ;;
        day)
          cutoff=$(date -d "-$((days - 1)) days" +%F)
          label=day
          title="last $days days"
          ;;
        month)
          cutoff=$(date -d "-$((months - 1)) months" +%Y-%m)
          label=month
          title="last $months months"
          ;;
      esac
      [ -n "$who" ] && title="$title, $who"
      true

      cat "$dir"/*.tsv |
        awk -F'\t' -v mode="$mode" -v cutoff="$cutoff" -v today="$today" -v who="$who" '
          {
            day = substr($1, 1, 10)
            mon = substr($1, 1, 7)
            if (who != "" && $2 != who) next
            if (mode == "today") {
              if (day != today) next
              k = $2
            } else if (mode == "day") {
              if (day < cutoff) next
              k = day
            } else {
              if (mon < cutoff) next
              k = mon
            }
            up[k] += $3 + 0
            down[k] += $4 + 0
            seen[k] = 1
          }
          END {
            for (k in seen) printf "%s %d %d\n", k, up[k], down[k]
          }
        ' |
        sort |
        awk -v label="$label" -v title="$title" '
          function human(b) {
            if (b >= 1099511627776) return sprintf("%.2f TiB", b / 1099511627776)
            if (b >= 1073741824) return sprintf("%.2f GiB", b / 1073741824)
            if (b >= 1048576) return sprintf("%.1f MiB", b / 1048576)
            if (b >= 1024) return sprintf("%.0f KiB", b / 1024)
            return sprintf("%d B", b)
          }
          function bar(v, m,   cnt, j, out) {
            cnt = (m > 0) ? int(v / m * 24 + 0.5) : 0
            out = ""
            for (j = 0; j < cnt; j++) out = out "#"
            return out
          }
          {
            n++
            key[n] = $1
            u[n] = $2
            d[n] = $3
            t[n] = $2 + $3
            if (t[n] > max) max = t[n]
            su += $2
            sd += $3
          }
          END {
            if (n == 0) {
              printf "\n %s: no traffic\n", title
              exit
            }
            printf "\n %s\n\n", title
            printf " %-12s %10s %10s %10s\n", label, "up", "down", "total"
            for (i = 1; i <= n; i++)
              printf " %-12s %10s %10s %10s  %s\n", key[i], human(u[i]), human(d[i]), human(t[i]), bar(t[i], max)
            printf " %-12s %10s %10s %10s\n", "total", human(su), human(sd), human(su + sd)
          }
        '
    '';
  };
in
{
  systemd.services.xray-traffic = {
    description = "Sample per-user traffic from the xray api";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe sampler;
    };
  };

  systemd.timers.xray-traffic = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "5min";
    };
  };

  environment.systemPackages = [ cli ];
}
