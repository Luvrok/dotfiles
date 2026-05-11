{ lib, ... }:

{
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";
  systemd.services.syncthing.serviceConfig.UMask = lib.mkForce "0002";

  users.users.syncthing = {
    isSystemUser = true;
    group = lib.mkForce "media";
  };

  services.syncthing = {
    enable = true;
    user = "syncthing";

    dataDir = "/var/lib/syncthing";
    configDir = "/var/lib/syncthing";
  };
}
