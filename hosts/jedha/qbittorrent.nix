{ config, lib, pkgs, ... }:

let
  betaninHook = pkgs.writeShellScript "qbittorrent-betanin-hook" ''
    [ "$1" = music ] || exit 0
    exec ${lib.getExe pkgs.curl} -fsS -X POST \
      -H @${config.sops.templates."qbittorrent-betanin-header".path} \
      --data-urlencode "both=$2" \
      http://127.0.0.1:9393/api/torrents
  '';
in
{
  users.users.qbittorrent = {
    isSystemUser = true;
    group = lib.mkForce "media";
  };

  systemd.services.qbittorrent.serviceConfig.UMask = lib.mkForce "0002";

  sops.templates."qbittorrent-betanin-header" = {
    owner = "qbittorrent";
    content = ''
      X-API-Key: ${config.sops.placeholder.betanin_api_key}
    '';
  };

  services.qbittorrent = {
    enable = true;
    user = "qbittorrent";
    group = "media";
    webuiPort = 8129;
    profileDir = "/var/lib/qbittorrent";
    torrentingPort = 51413;
    openFirewall = true;

    serverConfig = {
      Downloads = {
        SavePath = "/var/lib/media/downloads";
      };
      AutoRun = {
        enabled = true;
        program = "${betaninHook} %L %F";
      };
      Preferences.WebUI = {
        Password_PBKDF2 = "AdlI4JvcoZzFByY6dwJAEw==:D1k5ETcTQH8KByb9mTz065YBBV4uMmMyoc5tKoWjXv18cZ/hEJh6JZuMWTMibtbAe+ses/v0Qbl6t3nLLUHiRg==";
      };
    };
  };
}
