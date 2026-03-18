{ pkgs, ... }:

{
  services.activitywatch = {
    enable = true;
    package = pkgs.aw-server-rust;
    watchers = {
      aw-watcher-afk = {
        package = pkgs.activitywatch;
        settings = {
          timeout = 1000;
          poll_time = 5;
        };
      };

      aw-watcher-window = {
        package = pkgs.activitywatch;
        settings = {
          poll_time = 5;
          exclude_title = false;
        };
      };
    };
  };
}
