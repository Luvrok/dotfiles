{ config, pkgs, ... }:

let
  port = 8180;
  # xray "mixed" inbound, speaks both http and socks5
  proxy = "http://127.0.0.1:10808";
  secret = config.sops.secrets."miniflux/admin".path;

  # feeds to check the proxy and fetch original content, run once by hand
  testFeeds = [
    # blocked in russia, only works through xray
    "https://meduza.io/rss/all"
    # summaries only, the full text comes from the crawler
    "https://feeds.arstechnica.com/arstechnica/index"
  ];

  addTestFeeds = pkgs.writeShellApplication {
    name = "miniflux-add-test-feeds";
    runtimeInputs = with pkgs; [
      curl
      jq
    ];
    text = ''
      # shellcheck disable=SC1091
      source ${secret}
      api() {
        local path=$1
        shift
        curl -fsS --noproxy '*' -u "$ADMIN_USERNAME:$ADMIN_PASSWORD" \
          "http://127.0.0.1:${toString port}/v1/$path" "$@"
      }

      feeds=$(api feeds)
      for url in ${toString testFeeds}; do
        if jq -e --arg url "$url" 'any(.feed_url == $url)' <<<"$feeds" >/dev/null; then
          echo "exists: $url"
          continue
        fi
        api feeds -X POST -H 'Content-Type: application/json' \
          -d "$(jq -n --arg url "$url" '{feed_url: $url, crawler: true}')"
        echo " added: $url"
      done
    '';
  };
in
{
  # ADMIN_USERNAME=... and ADMIN_PASSWORD=... (6+ chars), env file format.
  # the seed script sources it too, so no quotes, spaces or $ in the password
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

  environment.systemPackages = [ addTestFeeds ];
}
