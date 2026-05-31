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

  services.lidarr = {
    enable = true;
    user = "lidarr";
    group = "lidarr";
    dataDir = "/var/lib/media/music";
    openFirewall = false;
  };

  systemd.services.lidarr.environment = {
    LIDARR__AUTH__METHOD = "Forms";
    LIDARR__AUTH__REQUIRED = "DisabledForLocalAddresses";
  };

  users.users.lidarr.extraGroups = [
    "media"
    "navidrome"
  ];

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
