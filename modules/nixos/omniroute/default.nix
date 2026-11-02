# omniroute: one openai-compatible endpoint in front of the free tiers
# (gemini, groq, cerebras, openrouter...), it moves on to the next provider
# when one runs out of quota. for opencode (modules/home/programs/opencode,
# the omniroute provider). the providers and their keys are added in its
# dashboard, http://127.0.0.1:20128, and kept in its database
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.omniroute;
  port = 20128;
  dataDir = "/var/lib/omniroute";
  # its own keys, made once on the host (below)
  secretsFile = "/var/lib/omniroute-secrets/env";
  # no latest: a release can migrate the database
  image = "docker.io/diegosouzapw/omniroute:3.8.52";
  # gemini answers "user location is not supported" to a direct request
  proxy = if config.services.xray.enable then "http://127.0.0.1:10808" else null;
in
{
  options.dotfiles.omniroute.enable = lib.mkEnableOption "omniroute, the free tiers behind one endpoint";

  config = lib.mkIf cfg.enable {
    # the image runs as node, uid 1000
    systemd.tmpfiles.rules = [ "d ${dataDir} 0750 1000 1000 -" ];

    # JWT_SECRET signs the dashboard's sessions, API_KEY_SECRET encrypts the
    # provider keys in the database: lose it and they have to be added again
    systemd.services.omniroute-secrets = {
      description = "Make omniroute's secret keys";
      before = [ "podman-omniroute.service" ];
      requiredBy = [ "podman-omniroute.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        StateDirectory = "omniroute-secrets";
        StateDirectoryMode = "0700";
        UMask = "0077";
      };
      script = ''
        [ -s ${secretsFile} ] && exit 0
        openssl=${lib.getExe pkgs.openssl}
        {
          echo "JWT_SECRET=$($openssl rand -base64 48 | tr -d '\n')"
          echo "API_KEY_SECRET=$($openssl rand -hex 32)"
        } > ${secretsFile}
      '';
    };

    virtualisation.oci-containers.containers.omniroute = {
      inherit image;
      environmentFiles = [ secretsFile ];
      environment = {
        PORT = toString port;
        # host network, so only loopback: the image binds 0.0.0.0
        HOSTNAME = "127.0.0.1";
        OMNIROUTE_SERVER_HOST = "127.0.0.1";
        DATA_DIR = "/app/data";
        # /v1 wants omniroute's own key (Dashboard, Endpoints): a web page
        # can reach 127.0.0.1 too
        REQUIRE_API_KEY = "true";
        # the admin password is set in the onboarding wizard
        INITIAL_PASSWORD = "";
        # no posing as chrome to the providers
        ENABLE_TLS_FINGERPRINT = "false";
      }
      // lib.optionalAttrs (proxy != null) {
        HTTP_PROXY = proxy;
        HTTPS_PROXY = proxy;
        http_proxy = proxy;
        https_proxy = proxy;
        NO_PROXY = "localhost,127.0.0.1";
        no_proxy = "localhost,127.0.0.1";
      };
      volumes = [ "${dataDir}:/app/data" ];
      extraOptions = [
        # xray's inbound and llama-swap are on the host's loopback
        "--network=host"
        "--memory=1536m"
      ];
    };
  };
}
