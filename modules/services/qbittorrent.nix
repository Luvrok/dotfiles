{ config, lib, ... }:

{
  options.galaxy.services.qbittorrent.enable = lib.mkEnableOption "qbittorrent-nox";

  config = lib.mkIf config.galaxy.services.qbittorrent.enable {
    galaxy.expose.qbittorrent = {
      port = 8129;
      subdomain = "qbt";
    };

    users.users.qbittorrent = {
      isSystemUser = true;
      group = lib.mkForce "media";
    };

    systemd.services.qbittorrent.serviceConfig.UMask = lib.mkForce "0002";

    services.qbittorrent = {
      enable = true;
      user = "qbittorrent";
      group = "media";
      webuiPort = config.galaxy.expose.qbittorrent.port;
      profileDir = "/var/lib/qbittorrent";
      torrentingPort = 51413;
      openFirewall = true;

      serverConfig = {
        Downloads = {
          SavePath = "/var/lib/media/downloads";
        };
        Preferences.WebUI = {
          Password_PBKDF2 = "AdlI4JvcoZzFByY6dwJAEw==:D1k5ETcTQH8KByb9mTz065YBBV4uMmMyoc5tKoWjXv18cZ/hEJh6JZuMWTMibtbAe+ses/v0Qbl6t3nLLUHiRg==";
        };
      };
    };
  };
}
