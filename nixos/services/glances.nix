{ pkgs, ... }:

{
  users.users.glances = {
    isSystemUser = true;
    group = "glances";
    description = "Glances monitoring service";
    home = "/var/lib/glances";
    createHome = true;
  };

  users.groups.glances = { };

  systemd.services.glances = {
    description = "Glances Web Interface";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];

    serviceConfig = {
      User = "glances";
      Group = "glances";
      ExecStart = "${pkgs.glances}/bin/glances -w --bind :: --port 61208 --time 3 --quiet";

      NoNewPrivileges = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      ReadWritePaths = [ "/var/lib/glances" ];
      RestrictSUIDSGID = true;
      RestrictRealtime = true;
      RestrictNamespaces = true;
      MemoryDenyWriteExecute = true;
      CapabilityBoundingSet = "";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
    };
  };
}
