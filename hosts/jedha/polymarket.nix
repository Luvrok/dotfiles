{
  config,
  lib,
  pkgs,
  ...
}:

let
  proxy = "http://127.0.0.1:10808";

  # events to watch, slug is the part after polymarket.com/event/. each one
  # takes either or both of:
  #   threshold  alert when a market's first outcome (usually Yes) moves by
  #              this many percentage points within window minutes
  #   every      report the top markets every this many hours, with the
  #              change since the previous report
  # null turns a kind off
  watch = {
    # example = {
    #   slug = "some-event-slug";
    #   threshold = 5;
    #   window = 60;
    #   every = 6;
    # };
  };

  checkEvery = "5min";

  defaults = {
    threshold = 5;
    window = 60;
    priority = 4;
    every = null;
    reportPriority = 2;
  };
  watchJson = pkgs.writeText "polymarket-watch.json" (
    builtins.toJSON (lib.mapAttrsToList (name: w: defaults // w // { inherit name; }) watch)
  );

  script = pkgs.writeShellApplication {
    name = "polymarket-watch";
    # $ in jq programs passed through update()
    excludeShellChecks = [ "SC2016" ];
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    text = ''
      : "''${NTFY_TOPIC:?NTFY_TOPIC is missing from the miniflux secret}"
      state=$STATE_DIRECTORY/state.json
      [[ -s $state ]] || echo '{"markets": {}, "reports": {}}' >"$state"
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

      update() {
        jq "$@" "$state" >"$state.new"
        mv "$state.new" "$state"
      }

      status=0
      while read -r w; do
        name=$(jq -r .name <<<"$w")
        slug=$(jq -r .slug <<<"$w")
        if ! event=$(fetch "$slug"); then
          echo "failed: $slug" >&2
          status=1
          continue
        fi
        title=$(jq -r .title <<<"$event")
        list=$(markets <<<"$event")
        click=https://polymarket.com/event/$slug

        if jq -e '.threshold != null' <<<"$w" >/dev/null; then
          # keep the samples inside the window, a move from the oldest one
          # beyond the threshold alerts and restarts the history
          result=$(jq -c --argjson m "$list" --argjson w "$w" --argjson now "$now" '
            reduce $m[] as $x ({markets: .markets, alerts: []};
              "\($w.name):\($x.id)" as $key
              | (.markets[$key].hist // [] | map(select(.ts >= $now - $w.window * 60))) as $hist
              | if ($hist | length) > 0 and (($x.p - $hist[0].p) | fabs) >= $w.threshold then
                  .alerts += [$x + {from: $hist[0].p, mins: (($now - $hist[0].ts) / 60 | round)}]
                  | .markets[$key].hist = [{ts: $now, p: $x.p}]
                else
                  .markets[$key].hist = $hist + [{ts: $now, p: $x.p}]
                end)' "$state")
          update --argjson r "$result" '.markets = $r.markets'

          while read -r a; do
            message=$(jq -r '"\(.name): \(.from)% → \(.p)% (\(if .p > .from then "+" else "" end)\(.p - .from | . * 10 | round / 10) п.п. за \(.mins) мин)"' <<<"$a")
            tag=$(jq -r 'if .p > .from then "chart_with_upwards_trend" else "chart_with_downwards_trend" end' <<<"$a")
            push "$title" "$message" "$(jq .priority <<<"$w")" "$click" "$tag" || status=1
          done < <(jq -c '.alerts[]' <<<"$result")
        fi

        if jq -e --arg name "$name" --argjson w "$w" --argjson now "$now" \
          '$w.every != null and $now - (.reports[$name].ts // 0) >= $w.every * 3600' "$state" >/dev/null; then
          # top 5 by price, change since the previous report
          message=$(jq -r --arg name "$name" --argjson m "$list" '
            (.reports[$name].p // {}) as $prev | $m | sort_by(-.p) | .[:5][]
            | $prev[.id] as $was
            | "\(.name): \(.p)%" + (if $was == null or $was == .p then ""
                else " (\(if .p > $was then "+" else "" end)\(.p - $was | . * 10 | round / 10))" end)' "$state")
          # a resolved event has no open markets left
          if [[ -z $message ]]; then
            :
          elif push "$title" "$message" "$(jq .reportPriority <<<"$w")" "$click" "bar_chart"; then
            update --arg name "$name" --argjson m "$list" --argjson now "$now" \
              '.reports[$name] = {ts: $now, p: ($m | map({key: .id, value: .p}) | from_entries)}'
          else
            status=1
          fi
        fi
      done < <(jq -c '.[]' ${watchJson})
      exit "$status"
    '';
  };
in
lib.mkIf (watch != { }) {
  systemd.services.polymarket-watch = {
    description = "Polymarket price alerts and reports";
    requires = [ "xray.service" ];
    after = [ "xray.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe script;
      # ntfy topic from the miniflux secret
      EnvironmentFile = config.sops.secrets."miniflux/admin".path;
      DynamicUser = true;
      StateDirectory = "polymarket-watch";
    };
  };

  systemd.timers.polymarket-watch = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = checkEvery;
    };
  };
}
