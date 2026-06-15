{ lib, ... }:

{
  users.users.audiobookshelf = {
    isSystemUser = true;
    group = lib.mkForce "media";
  };

  services.audiobookshelf = {
    enable = true;
    port = 4544;
    host = "::";
    user = "audiobookshelf";
    group = "media";
    openFirewall = true;
    dataDir = "audiobookshelf";
  };

  systemd.services.audiobookshelf = {
    serviceConfig = {
      UMask = lib.mkForce "0002";
    };
  };
}
