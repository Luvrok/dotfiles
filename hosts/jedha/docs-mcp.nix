# docs-mcp-server: scrapes docs into a sqlite index, serves search over MCP,
# web ui and api on one port. vectors come from llama-server (embeddings.nix)
{
  config,
  lib,
  pkgs,
  ...
}:

let
  port = 6280;
  dataDir = "/var/lib/docs-mcp";
  # set to the external url (e.g. "https://docs.example.com") when a proxy
  # sends another Host header, the server answers 403 to names it doesn't know
  publicUrl = null;
  llama = config.services.llama-cpp.settings;

  # an explicit config file is read only, the server never writes it
  configFile = (pkgs.formats.json { }).generate "docs-mcp.json" (
    {
      app = {
        telemetryEnabled = false; # posthog is on by default
        embeddingModel = llama.alias;
      };
    }
    // lib.optionalAttrs (publicUrl != null) { server = { inherit publicUrl; }; }
  );
in
{
  # the image runs as uid 1000
  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 1000 1000 -" ];

  virtualisation.oci-containers.containers.docs-mcp = {
    # no latest, a new release can migrate the db
    image = "ghcr.io/arabold/docs-mcp-server:3.3.0";
    extraOptions = [
      "--network=host"
      "--memory=1536m"
    ];

    environment = {
      # full names: the image sets HOST=0.0.0.0 and PORT, aliases beat the config file
      DOCS_MCP_SERVER_HOST = "127.0.0.1";
      DOCS_MCP_SERVER_PORTS_DEFAULT = toString port;
      DOCS_MCP_CONFIG = "/etc/docs-mcp/config.json";
      OPENAI_API_BASE = "http://127.0.0.1:${toString llama.port}/v1";
      OPENAI_API_KEY = "none";
    };

    volumes = [
      "${dataDir}:/data"
      "${configFile}:/etc/docs-mcp/config.json:ro"
    ];
  };

  systemd.services.podman-docs-mcp = {
    wants = [ "llama-cpp.service" ];
    after = [ "llama-cpp.service" ];
    # the first start asks the model for its vector size, so wait for the model
    serviceConfig.ExecStartPre = lib.mkAfter [
      "${lib.getExe pkgs.curl} -sf -o /dev/null --retry 30 --retry-delay 2 --retry-all-errors http://127.0.0.1:${toString llama.port}/health"
    ];
  };
}
