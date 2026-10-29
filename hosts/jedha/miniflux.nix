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

  # feeds managed from here: missing ones are added, settings are reapplied
  # on every switch. a feed dropped from the list stays in miniflux, delete
  # it in the ui. attrs are api fields
  # (https://miniflux.app/docs/api.html#endpoint-update-feed), except
  # category, which is a title and gets created if missing
  feeds = {
    # blocked in russia, only works through xray
    "https://meduza.io/rss/all" = {
      category = "News";
      crawler = true;
    };
    # summaries only, the full text comes from the crawler
    "https://feeds.arstechnica.com/arstechnica/index" = {
      category = "Tech";
      crawler = true;
    };
  };

  syncFeeds = pkgs.writeShellApplication {
    name = "miniflux-sync-feeds";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    text = ''
      api() {
        local method=$1 path=$2
        shift 2
        curl -fsS --noproxy '*' -X "$method" -u "$ADMIN_USERNAME:$ADMIN_PASSWORD" \
          -H 'Content-Type: application/json' \
          "http://127.0.0.1:${toString port}/v1/$path" "$@"
      }

      category_id() {
        local id
        id=$(api GET categories | jq -e --arg t "$1" 'first(.[] | select(.title == $t)) | .id') ||
          id=$(api POST categories -d "$(jq -n --arg t "$1" '{title: $t}')" | jq .id)
        echo "$id"
      }

      existing=$(api GET feeds)
      status=0
      while read -r entry; do
        url=$(jq -r .key <<<"$entry")
        settings=$(jq -c .value <<<"$entry")
        if category=$(jq -er '.category // empty' <<<"$settings"); then
          settings=$(jq -c --argjson id "$(category_id "$category")" \
            'del(.category) + {category_id: $id}' <<<"$settings")
        fi

        if id=$(jq -e --arg url "$url" 'first(.[] | select(.feed_url == $url)) | .id' <<<"$existing"); then
          action=updated
          request=(PUT "feeds/$id" -d "$settings")
        else
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
      done < <(jq -c 'to_entries[]' ${pkgs.writeText "miniflux-feeds.json" (builtins.toJSON feeds)})
      exit "$status"
    '';
  };
in
{
  # ADMIN_USERNAME=... and ADMIN_PASSWORD=... (6+ chars), env file format
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
    };
  };

  systemd.services.miniflux-sync-feeds = {
    description = "Sync miniflux feeds with the nix list";
    wantedBy = [ "multi-user.target" ];
    requires = [ "miniflux.service" ];
    after = [ "miniflux.service" ];
    # the list is baked into ExecStart, so a changed list reruns it on switch
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = lib.getExe syncFeeds;
      EnvironmentFile = secret;
      DynamicUser = true;
    };
  };
}
