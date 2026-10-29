{
  config,
  lib,
  pkgs,
  ...
}:

let
  proxy = "http://127.0.0.1:10808";

  # events to watch, slug is the part after polymarket.com/event/.
  # an alert fires when a market's first outcome (usually Yes) moves by
  # threshold percentage points within window minutes
  watch = {
    # example = {
    #   slug = "some-event-slug";
    #   threshold = 5;
    #   window = 60;
    #   priority = 4;
    # };
  };

  checkEvery = "5min";
  # OnCalendar for the summary of all watched events, null turns it off
  summaryAt = "hourly";

  defaults = {
    threshold = 5;
    window = 60;
    priority = 4;
  };
  watchJson = pkgs.writeText "polymarket-watch.json" (
    builtins.toJSON (map (w: defaults // w) (lib.attrValues watch))
  );

  script = pkgs.writeShellApplication {
    name = "polymarket-watch";
    runtimeInputs = with pkgs; [
      curl
      jq
      util-linux
    ];
    text = ''
      mode=$1
      : "''${NTFY_TOPIC:?NTFY_TOPIC is missing from the miniflux secret}"
      state=$STATE_DIRECTORY/state.json
      exec 9>"$STATE_DIRECTORY/lock"
      flock 9
      [[ -s $state ]] || echo '{}' >"$state"
      now=$(date +%s)

      fetch() {
        curl -fsS --max-time 30 -x ${proxy} "https://gamma-api.polymarket.com/events/slug/$1"
      }

      # title, message, priority, click url, tags
      push() {
        jq -n --arg topic "$NTFY_TOPIC" --arg title "$1" --arg message "$2" \
          --argjson priority "$3" --arg click "$4" --arg tags "$5" \
          '{$topic, $title, $message, $priority, $click, tags: ($tags | split(","))}' |
          curl -fsS --max-time 30 -x ${proxy} -d @- https://ntfy.sh >/dev/null
      }

      # open markets as {id, name, p}, p is the first outcome in percent
      markets() {
        jq -c '[.markets[]
          | select(.closed != true and .active != false and .outcomePrices != null)
          | {id, name: (.groupItemTitle // .question),
             p: ((.outcomePrices | fromjson)[0] | tonumber * 1000 | round / 10)}]'
      }

      status=0
      summary=""
      while read -r w; do
        slug=$(jq -r .slug <<<"$w")
        if ! event=$(fetch "$slug"); then
          echo "failed: $slug" >&2
          status=1
          continue
        fi
        title=$(jq -r .title <<<"$event")
        list=$(markets <<<"$event")

        if [[ $mode == check ]]; then
          # keep the samples inside the window, a move from the oldest one
          # beyond the threshold alerts and restarts the history
          result=$(jq -c --argjson m "$list" --argjson w "$w" --argjson now "$now" '
            reduce $m[] as $x ({state: ., alerts: []};
              (.state[$x.id].hist // [] | map(select(.ts >= $now - $w.window * 60))) as $hist
              | if ($hist | length) > 0 and (($x.p - $hist[0].p) | fabs) >= $w.threshold then
                  .alerts += [$x + {from: $hist[0].p, mins: (($now - $hist[0].ts) / 60 | round)}]
                  | .state[$x.id].hist = [{ts: $now, p: $x.p}]
                else
                  .state[$x.id].hist = $hist + [{ts: $now, p: $x.p}]
                end)' "$state")
          jq '.state' <<<"$result" >"$state"

          while read -r a; do
            [[ -n $a ]] || continue
            message=$(jq -r '"\(.name): \(.from)% → \(.p)% (\(if .p > .from then "+" else "" end)\(.p - .from | . * 10 | round / 10) п.п. за \(.mins) мин)"' <<<"$a")
            tag=$(jq -r 'if .p > .from then "chart_with_upwards_trend" else "chart_with_downwards_trend" end' <<<"$a")
            push "$title" "$message" "$(jq .priority <<<"$w")" "https://polymarket.com/event/$slug" "$tag" ||
              status=1
          done < <(jq -c '.alerts[]' <<<"$result")
        else
          # top 5 by price, change since the previous summary
          lines=$(jq -r --argjson m "$list" '
            . as $s | $m | sort_by(-.p) | .[:5][]
            | ($s[.id].sum // null) as $prev
            | "  \(.name): \(.p)%" + (if $prev == null or $prev == .p then ""
                else " (\(if .p > $prev then "+" else "" end)\(.p - $prev | . * 10 | round / 10))" end)' "$state")
          summary+="$title"$'\n'"$lines"$'\n\n'
          jq --argjson m "$list" 'reduce $m[] as $x (.; .[$x.id].sum = $x.p)' "$state" >"$state.new"
          mv "$state.new" "$state"
        fi
      done < <(jq -c '.[]' ${watchJson})

      if [[ $mode == summary && -n $summary ]]; then
        push "Polymarket: сводка" "''${summary%$'\n\n'}" 2 "https://polymarket.com" "bar_chart" ||
          status=1
      fi
      exit "$status"
    '';
  };

  mkService = mode: {
    description = "Polymarket watch (${mode})";
    requires = [ "xray.service" ];
    after = [ "xray.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe script} ${mode}";
      # ntfy topic from the miniflux secret
      EnvironmentFile = config.sops.secrets."miniflux/admin".path;
      # both units share the user and the state
      DynamicUser = true;
      User = "polymarket-watch";
      StateDirectory = "polymarket-watch";
    };
  };
in
lib.mkIf (watch != { }) {
  systemd.services = {
    polymarket-watch-check = mkService "check";
  }
  // lib.optionalAttrs (summaryAt != null) {
    polymarket-watch-summary = mkService "summary";
  };

  systemd.timers = {
    polymarket-watch-check = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = checkEvery;
      };
    };
  }
  // lib.optionalAttrs (summaryAt != null) {
    polymarket-watch-summary = {
      wantedBy = [ "timers.target" ];
      timerConfig.OnCalendar = summaryAt;
    };
  };
}
