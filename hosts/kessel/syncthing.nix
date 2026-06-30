{
  pkgs,
  lib,
  username,
  ...
}:

{
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";
  systemd.services.syncthing.serviceConfig.UMask = lib.mkForce "0002";

  users.users.syncthing = {
    isSystemUser = true;
  };

  users.users.syncthing.extraGroups = [
    "media"
    "navidrome"
  ];

  services.syncthing = {
    enable = true;
    user = "syncthing";
    openDefaultPorts = true;

    dataDir = "/var/lib/syncthing";
    configDir = "/var/lib/syncthing";

    # relay = {
    #   enable = true;
    #   port = 22067;
    #   statusPort = 22070;
    #   pools = [ "" ];
    #
    #   providedBy = "delroth (${username})";
    #
    #   globalRateBps = lib.mkDefault (20 * 1024 * 1024); # 20MB/s
    #   perSessionRateBps = lib.mkDefault (5 * 1024 * 1024); # 5MB/s
    # };
  };

  # users.users.stdiscosrv = {
  #   isSystemUser = true;
  #   group = "stdiscosrv";
  #   home = "/var/lib/stdiscosrv";
  #   createHome = true;
  # };
  #
  # users.groups.stdiscosrv = { };

  # systemd.services.syncthing-discovery = {
  #   description = "Syncthing Discovery Server";
  #   after = [ "network.target" ];
  #   wantedBy = [ "multi-user.target" ];
  #   serviceConfig = {
  #     User = "stdiscosrv";
  #     Group = "stdiscosrv";
  #     ExecStart = "${pkgs.syncthing-discovery}/bin/stdiscosrv --listen 127.0.0.1:8443 --db-dir /var/lib/syncthing-discovery";
  #     Restart = "on-failure";
  #     RestartSec = 5;
  #     WorkingDirectory = "/var/lib/stdiscosrv";
  #     StateDirectory = "syncthing-discovery";
  #     ProtectSystem = "strict";
  #     ProtectHome = true;
  #     NoNewPrivileges = true;
  #     PrivateTmp = true;
  #   };
  # };
}
