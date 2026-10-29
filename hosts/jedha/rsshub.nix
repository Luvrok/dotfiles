{ ... }:

{
  # turns telegram channels and sites without rss into feeds for miniflux,
  # listens on 127.0.0.1:1200 only
  services.rsshub = {
    enable = true;
    settings = {
      # t.me is throttled here
      PROXY_URI = "http://127.0.0.1:10808";
      # route cache, 5 min by default. shorter so a frequent refresh sees new posts
      CACHE_EXPIRE = "60";
    };
  };
}
