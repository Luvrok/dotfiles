{ config, lib, ... }:

{
  options.galaxy.services.navidrome.enable = lib.mkEnableOption "navidrome";

  config = lib.mkIf config.galaxy.services.navidrome.enable {
    galaxy.expose.navidrome = {
      port = 4533;
      subdomain = "navidrome";
    };

    users.users.navidrome = {
      isSystemUser = true;
      group = lib.mkForce "media";
    };

    systemd.services.navidrome = {
      requires = [ "systemd-tmpfiles-setup.service" ];
    };

    systemd.tmpfiles.settings = {
      navidromeDirs = {
        "/run/navidrome".d = {
          mode = "2775";
          user = "navidrome";
          group = "media";
        };
      };
    };

    services.navidrome = {
      enable = true;
      openFirewall = true;
      settings = {
        Address = "[::]";
        Port = config.galaxy.expose.navidrome.port;
        Scanner.Enabled = true;
        Scanner.WatcherWait = "1m";
        DataFolder = "/persist/navidrome";
        MusicFolder = "/var/lib/media/music";
        ScanSchedule = "@every 1h";

        EnableSharing = true;
        DefaultShareExpiration = "2h";
        ShareURL = "https://navidrome.vxrnt.ru";

        ListenBrainz.Enabled = true;
        ListenBrainz.BaseURL = "http://127.0.0.1:${toString config.galaxy.expose.koito.port}/apis/listenbrainz/1/";

        Backup = {
          Path = "/var/backup/navidrome";
          Schedule = "0 14 * * *";
          Count = 1;
        };
      };
    };
  };
}
