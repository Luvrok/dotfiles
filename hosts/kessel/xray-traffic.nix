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
  # to a monthly tsv. missing a run loses that slice, nothing else.
  #
  # xray leaves `value` out entirely when a counter is still zero, so it must
  # never reach tonumber as null: that made jq exit 5 and the whole sample die
  # for as long as any of the eight users was idle
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

      if ! stats=$(xray api statsquery --server=127.0.0.1:10085 -pattern 'user>>>' -reset=true); then
        echo "statsquery failed, this slice is lost" >&2
        exit 0
      fi
      [ -n "$stats" ] || exit 0

      ts=$(date '+%Y-%m-%d %H:%M')
      month=$(date +%Y-%m)

      # a reset already happened in xray, so a half-written sample is bytes
      # lost for good: build the rows in a temp file and append them in one go
      tmp=$(mktemp)
      trap 'rm -f "$tmp"' EXIT

      printf '%s' "$stats" | jq -r --arg ts "$ts" '
        [ .stat[]? | select(.name | startswith("user>>>")) | { name: .name, value: ((.value // "0") | tonumber) } ]
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
      ' > "$tmp"

      [ -s "$tmp" ] || exit 0
      cat "$tmp" >> "$dir/$month.tsv"

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
      mode=user
      window=days
      days=7
      months=6
      who=""

      usage() {
        cat <<'EOF'
      usage: xray-traffic [-d [n]] [-m [n]] [-u email]

        (no option)  last 30 days, one row per user
        -d [n]       last n days (7 by default), one row per day
        -m [n]       last n months (6 by default), one row per user
        -u email     only that user, works with every mode, in any order

      every table ends with a total row
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
            mode=user
            window=months
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

      case "$mode" in
        day)
          cutoff=$(date -d "-$((days - 1)) days" +%F)
          label=day
          if [ "$days" -eq 1 ]; then title=today; else title="last $days days"; fi
          ;;
        user)
          label=user
          if [ "$window" = months ]; then
            cutoff=$(date -d "-$months months" +%F)
            if [ "$months" -eq 1 ]; then title="last month"; else title="last $months months"; fi
          else
            cutoff=$(date -d "-29 days" +%F)
            title="last 30 days"
          fi
          ;;
      esac
      [ -n "$who" ] && title="$title, $who"
      true

      cat "$dir"/*.tsv |
        awk -F'\t' -v mode="$mode" -v cutoff="$cutoff" -v who="$who" '
          {
            day = substr($1, 1, 10)
            if (who != "" && $2 != who) next
            if (day < cutoff) next
            k = (mode == "day") ? day : $2
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
    wants = [ "xray.service" ];
    after = [ "xray.service" ];
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
