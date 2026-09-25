{ config, pkgs, lib, ... }:

let
  port = 5390;
  basePath = "/subtitle-translator";
  nodejs = pkgs.nodejs_24;

  app = pkgs.buildNpmPackage {
    pname = "subtitle-translator";
    version = "1.3.0-unstable-2026-09-25";
    inherit nodejs;

    src = pkgs.fetchFromGitHub {
      owner = "Luvrok";
      repo = "subtitle-translator";
      rev = "719651be2fff2316f8c8541a30da125b30bb9aab";
      hash = "sha256-DeGIE5GttibBs377/xNqggIVeGGhoDBQgH9fsgx/J1g=";
    };

    npmDepsHash = "sha256-NBhRUcamqdvycgdwzQ2DM+Njb0m5lpg3n5JdpgmsRQk=";
    env.PUBLIC_URL = basePath;

    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r build $out/public
      cp -r server lib $out/
      runHook postInstall
    '';
  };
in
{
  systemd.services.subtitle-translator = {
    description = "Subtitle Translator (frontend + backend)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" "libretranslate.service" ];
    wants = [ "libretranslate.service" ];

    environment = {
      HOST = "127.0.0.1";
      PORT = toString port;
      BASE_PATH = basePath;
      STATIC_DIR = "${app}/public";
      LT_URL = "http://[::1]:${toString config.services.libretranslate.port}";
      MAX_ACTIVE = "1"; # files translated at once, the rest wait in a queue
      MAX_QUEUE = "20"; # queued files beyond this get "server is busy"
      JOB_TIMEOUT_S = "1800"; # one file, queue wait excluded
      BATCH_TIMEOUT_S = "300"; # one LibreTranslate call
      BATCH_CHARS = "4000"; # text per LibreTranslate call, ~100 lines
      PARALLEL_BATCHES = "2"; # LibreTranslate calls per file at once, keep equal to ARGOS_INTER_THREADS
    };

    serviceConfig = {
      ExecStart = "${lib.getExe nodejs} ${app}/server/server.mjs";
      DynamicUser = true;
      Restart = "on-failure";

      NoNewPrivileges = true;
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      PrivateDevices = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
      RestrictNamespaces = true;
      LockPersonality = true;
      CapabilityBoundingSet = "";
    };
  };

  networking.firewall.allowedTCPPorts = [ port ];
}
