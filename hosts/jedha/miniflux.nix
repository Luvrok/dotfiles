{
  config,
  lib,
  pkgs,
  ...
}:

let
  port = 8180;
  # xray "mixed" inbound, speaks both http and socks5
  proxy = "http://127.0.0.1:10808";
  secret = config.sops.secrets."miniflux/admin".path;

  rsshub = "http://127.0.0.1:${toString config.services.rsshub.settings.PORT}";

  # top posts of a subreddit over t (day, week), cut to the first limit, so a
  # post shows up once it climbs into them. no crawler, the link is the
  # comments page
  reddit = category: sub: t: limit: {
    url = "https://www.reddit.com/r/${sub}/top/.rss?t=${t}&limit=${toString limit}";
    inherit category;
  };

  # feeds managed from here: missing ones are added, settings are reapplied
  # on every switch and boot. a feed dropped from the list stays in miniflux,
  # delete it in the ui. besides url, attrs are api fields
  # (https://miniflux.app/docs/api.html#endpoint-update-feed), except
  # category, which is a title and gets created if missing, refresh, a
  # systemd time span to poll the feed on top of miniflux's hourly round, and
  # ntfy, a push priority 1-5 for new entries (false turns pushes off)
  feeds = {
    ateo = {
      url = "${rsshub}/telegram/channel/Ateobreaking";
      category = "Breaking";
      refresh = "2min";
    };
    meduza = {
      # blocked in russia, only works through xray
      url = "https://meduza.io/rss/all";
      category = "Breaking";
      refresh = "10min";
      crawler = true;
      # news only, no podcasts, features or games
      keep_filter_entry_rules = "EntryURL=^https://meduza\\.io/news/";
    };
    npr-world = {
      url = "https://feeds.npr.org/1004/rss.xml";
      category = "World";
      crawler = true;
    };
    bbc-world = {
      url = "https://feeds.bbci.co.uk/news/world/rss.xml";
      category = "World";
      crawler = true;
    };
    badcomedian = {
      # shorts are filtered out by rsshub
      url = "${rsshub}/youtube/user/@TheBadComedian";
      category = "YouTube";
      ntfy = 5;
    };
    reddit-worldnews = reddit "World" "worldnews" "day" 10;
    reddit-europe = reddit "World" "europe" "day" 7;
    reddit-geopolitics = reddit "World" "geopolitics" "day" 7;
    reddit-news = reddit "US" "news" "day" 10;
    reddit-politics = reddit "US" "politics" "day" 10;
    # polls, election maps, charts
    reddit-fivethirtyeight = reddit "Data" "fivethirtyeight" "day" 5;
    reddit-dataisbeautiful = reddit "Data" "dataisbeautiful" "day" 5;
    reddit-mapporn = reddit "Data" "MapPorn" "day" 5;
    reddit-osint = reddit "Investigations" "OSINT" "week" 5;
    bellingcat = {
      url = "https://www.bellingcat.com/feed/";
      category = "Investigations";
    };
    icij = {
      url = "https://www.icij.org/feed/";
      category = "Investigations";
      crawler = true;
    };
  };

  refreshed = lib.filterAttrs (_: feed: feed ? refresh) feeds;

  api = ''
    api() {
      local method=$1 path=$2
      shift 2
      curl -fsS --noproxy '*' --max-time 120 -X "$method" -u "$ADMIN_USERNAME:$ADMIN_PASSWORD" \
        -H 'Content-Type: application/json' \
        "http://127.0.0.1:${toString port}/v1/$path" "$@"
    }
  '';

  syncFeeds = pkgs.writeShellApplication {
    name = "miniflux-sync-feeds";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    text = api + ''
      category_id() {
        local id
        id=$(api GET categories | jq -e --arg t "$1" 'first(.[] | select(.title == $t)) | .id') ||
          id=$(api POST categories -d "$(jq -n --arg t "$1" '{title: $t}')" | jq .id)
        echo "$id"
      }

      # rsshub is node and takes a few seconds to listen after its unit starts
      curl -fsS --noproxy '*' -o /dev/null --retry 30 --retry-delay 2 --retry-all-errors ${rsshub}/ ||
        echo "rsshub isn't up, its feeds will fail" >&2

      existing=$(api GET feeds)
      status=0
      declare -A added

      # newest arrivals on top: by arrival, not publish date, so an hourly feed
      # doesn't sink under one polled every 2 minutes
      api PUT "users/$(api GET me | jq .id)" \
        -d '{"entry_sorting_order": "created_at", "entry_sorting_direction": "desc"}' >/dev/null ||
        status=1
      while read -r feed; do
        url=$(jq -r .url <<<"$feed")
        settings=$(jq -c 'del(.url, .refresh, .ntfy)' <<<"$feed")
        if category=$(jq -er '.category // empty' <<<"$settings"); then
          settings=$(jq -c --argjson id "$(category_id "$category")" \
            'del(.category) + {category_id: $id}' <<<"$settings")
        fi

        if id=$(jq -e --arg url "$url" 'first(.[] | select(.feed_url == $url)) | .id' <<<"$existing"); then
          action=updated
          request=(PUT "feeds/$id" -d "$settings")
        else
          # adding a feed fetches it right away, and reddit answers a burst
          # with 429, so space out new feeds from the same host
          host=''${url#*://}
          host=''${host%%/*}
          if [[ -n ''${added[$host]:-} ]]; then
            sleep 30
          fi
          added[$host]=1
          action="  added"
          request=(POST feeds -d "$(jq -c --arg url "$url" '. + {feed_url: $url}' <<<"$settings")")
        fi

        # one dead feed shouldn't stop the rest
        if api "''${request[@]}" >/dev/null; then
          echo "$action: $url"
        else
          echo " failed: $url" >&2
          status=1
        fi
      done < <(jq -c '.[]' ${pkgs.writeText "miniflux-feeds.json" (builtins.toJSON (lib.attrValues feeds))})
      exit "$status"
    '';
  };

  # the api has no ntfy fields, so they go straight into the database
  quote = str: "'${lib.replaceStrings [ "'" ] [ "''" ] str}'";
  ntfyFeeds = lib.filterAttrs (_: feed: feed ? ntfy) feeds;
  ntfySql = pkgs.writeText "miniflux-ntfy.sql" (
    lib.concatMapStrings (
      feed:
      if feed.ntfy == false then
        "UPDATE feeds SET ntfy_enabled = false WHERE feed_url = ${quote feed.url};\n"
      else
        "UPDATE feeds SET ntfy_enabled = true, ntfy_priority = ${toString feed.ntfy} WHERE feed_url = ${quote feed.url};\n"
    ) (lib.attrValues ntfyFeeds)
  );

  syncNtfy = pkgs.writeShellApplication {
    name = "miniflux-sync-ntfy";
    runtimeInputs = [ config.services.postgresql.package ];
    text = ''
      psql() {
        command psql -v ON_ERROR_STOP=1 -d miniflux "$@"
      }

      # NTFY_TOPIC in the admin secret turns the integration on, empty url is ntfy.sh
      if [[ -n ''${NTFY_TOPIC:-} ]]; then
        psql -v user="$ADMIN_USERNAME" -v topic="$NTFY_TOPIC" <<'SQL'
      UPDATE integrations SET ntfy_enabled = true, ntfy_topic = :'topic'
        WHERE user_id = (SELECT id FROM users WHERE username = :'user');
      SQL
      fi
      psql -f ${ntfySql}
    '';
  };

  refreshFeed = pkgs.writeShellApplication {
    name = "miniflux-refresh-feed";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    text = api + ''
      feed=$(api GET feeds | jq -ce --arg url "$1" 'first(.[] | select(.feed_url == $url))')
      # a manual refresh ignores "do not refresh this feed" from the ui
      if jq -e .disabled <<<"$feed" >/dev/null; then
        exit 0
      fi
      api PUT "feeds/$(jq .id <<<"$feed")/refresh"
    '';
  };

  serviceConfig = {
    Type = "oneshot";
    EnvironmentFile = secret;
    DynamicUser = true;
  };
in
{
  # ADMIN_USERNAME=... and ADMIN_PASSWORD=... (6+ chars), env file format.
  # optional NTFY_TOPIC=... turns on ntfy pushes
  sops.secrets."miniflux/admin" = {
    restartUnits = [ "miniflux.service" ];
  };

  services.miniflux = {
    enable = true;
    adminCredentialsFile = secret;
    config = {
      LISTEN_ADDR = "127.0.0.1:${toString port}";
      BASE_URL = "https://rss.vxrnt.ru";
      HTTPS = 1;

      # images go through miniflux, so clients don't hit blocked cdns themselves
      MEDIA_PROXY_MODE = "all";
      MEDIA_PROXY_RESOURCE_TYPES = "image";

      # HTTP_CLIENT_PROXIES covers feeds and the crawler but not the media proxy,
      # the env proxy covers everything. the env proxy itself is 127.0.0.1, which
      # the private network filter blocks, so the filter is off. fine while
      # i'm the only user
      HTTP_PROXY = proxy;
      HTTPS_PROXY = proxy;
      FETCHER_ALLOW_PRIVATE_NETWORKS = 1;
      # same for integrations (ntfy): with the filter on, their client skips
      # the env proxy and goes straight out
      INTEGRATION_ALLOW_PRIVATE_NETWORKS = 1;

      # reddit answers a burst with 429. the scheduler wakes every 5 min and
      # takes at most one feed per host each time, so reddit's feeds are
      # spread over the hour. each feed is still polled hourly, that's
      # SCHEDULER_ROUND_ROBIN_MIN_INTERVAL
      POLLING_FREQUENCY = 5;
      POLLING_LIMIT_PER_HOST = 1;
    };
  };

  systemd.services = {
    miniflux-sync-feeds = {
      description = "Sync miniflux feeds with the nix list";
      wantedBy = [ "multi-user.target" ];
      requires = [ "miniflux.service" ];
      wants = [ "rsshub.service" ];
      after = [
        "miniflux.service"
        "rsshub.service"
      ];
      # the list is baked into ExecStart, so a changed list reruns it on switch
      serviceConfig = serviceConfig // {
        RemainAfterExit = true;
        ExecStart = lib.getExe syncFeeds;
      };
    };

    # separate unit, so a failed feed in the sync above doesn't skip it
    miniflux-sync-ntfy = {
      description = "Sync miniflux ntfy settings with the nix list";
      wantedBy = [ "multi-user.target" ];
      requires = [ "miniflux.service" ];
      after = [ "miniflux-sync-feeds.service" ];
      # rerun along with the sync, so feeds it adds later get their pushes too
      partOf = [ "miniflux-sync-feeds.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "postgres";
        EnvironmentFile = secret;
        ExecStart = lib.getExe syncNtfy;
      };
    };
  }
  // lib.mapAttrs' (
    name: feed:
    lib.nameValuePair "miniflux-refresh-${name}" {
      description = "Refresh miniflux feed ${name}";
      requires = [ "miniflux.service" ];
      after = [ "miniflux-sync-feeds.service" ];
      serviceConfig = serviceConfig // {
        ExecStart = "${lib.getExe refreshFeed} ${lib.escapeShellArg feed.url}";
      };
    }
  ) refreshed;

  systemd.timers = lib.mapAttrs' (
    name: feed:
    lib.nameValuePair "miniflux-refresh-${name}" {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "2min";
        OnUnitActiveSec = feed.refresh;
      };
    }
  ) refreshed;
}
