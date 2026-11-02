# kiss-worker.nix
{ config, lib, pkgs, ... }:

let
  cfg = config.services.kiss-worker;

  kiss-worker = pkgs.buildGoModule {
    pname = "kiss-worker";
    version = "unstable-2026-09-25";

    src = pkgs.fetchFromGitHub {
      owner = "fishjar";
      repo = "kiss-worker";
      rev = "master";
      hash = "sha256-frA4Z95Bp7l9yPulaGJ0gbiEq52wfk21vKrrrdXTWjc=";
    };

    vendorHash = "sha256-zfXbjvy+OULkNGiXdIwnZ2cU9S5ns6zTav70CvB6trI=";
    doCheck = false;

    meta.mainProgram = "kiss-worker";
  };
in
{
  options.services.kiss-worker = {
    enable = lib.mkEnableOption "kiss-worker sync server for KISS-Translator";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
    };

    listenAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
    };

    environmentFile = lib.mkOption {
      type = lib.types.path;
      description = "File containing APP_KEY=...";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.kiss-worker = {
      description = "kiss-worker sync server";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      environment = {
        GIN_MODE = "release";
        PORT = toString cfg.port;
        APP_DATAPATH = "/var/lib/kiss-worker";
      };

      serviceConfig = {
        ExecStart = lib.getExe kiss-worker;
        EnvironmentFile = cfg.environmentFile;
        DynamicUser = true;
        StateDirectory = "kiss-worker";
        WorkingDirectory = "/var/lib/kiss-worker";
        Restart = "on-failure";

        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        SystemCallArchitectures = "native";
        CapabilityBoundingSet = "";
      };
    };
  };
}
