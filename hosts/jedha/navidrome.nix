{ lib, ... }:

{
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
      Port = 4533;
      Scanner.Enabled = true;
      Scanner.WatcherWait = "1m";
      DataFolder = "/persist/navidrome";
      MusicFolder = "/var/lib/media/music";
      ScanSchedule = "@every 1h";

      ListenBrainz.Enabled = true;
      LastFM.Enabled = true;
      LastFM.ScrobbleFirstArtistOnly = true; # lastfm doesn't support multiple artists very well

      Backup = {
        Path = "/var/backup/navidrome";
        Schedule = "0 14 * * *";
        Count = 1;
      };
    };
  };
}
