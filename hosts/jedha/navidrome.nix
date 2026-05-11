{ lib, ... }:

{
  users.users.navidrome = {
    isSystemUser = true;
    group = lib.mkForce "media";
  };

  systemd.services.navidrome.serviceConfig.UMask = lib.mkForce "0002";

  services.navidrome = {
    enable = true;
    openFirewall = true;
    settings = {
      Address = "[::]";
      Port = 4533;
      DataFolder = "/persist/navidrome";
      MusicFolder = "/var/lib/media/music";
    };
  };
}
