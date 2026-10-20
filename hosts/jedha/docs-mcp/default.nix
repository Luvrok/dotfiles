# docs-mcp-server: docs in a sqlite index, read-only search over MCP. the docs
# are in sources.nix, the sync timers scrape them with the cli. vectors come
# from llama-server (embeddings.nix)
{
  config,
  lib,
  pkgs,
  ...
}:

let
  port = 6280;
  dataDir = "/var/lib/docs-mcp";
  # no latest, a new release can migrate the db
  image = "ghcr.io/arabold/docs-mcp-server:3.3.0";
  # set to the external url (e.g. "https://docs.example.com") when a proxy
  # sends another Host header, the server answers 403 to names it doesn't know
  publicUrl = "https://docs.vxrnt.ru";
  # every scrape goes out through the xray http inbound, some doc sites are
  # blocked from here. null to go direct
  proxy = "http://127.0.0.1:10808";
  sources = import ./sources.nix { inherit pkgs config; };
  # devdocs and local sources are copied here as plain html first
  filesDir = "/var/lib/docs-mcp-sync/files";
  filesMount = "/sources";
  llama = config.services.llama-cpp.settings;
  podman = lib.getExe config.virtualisation.podman.package;

  configFile = (pkgs.formats.json { }).generate "docs-mcp.json" (
    {
      app = {
        telemetryEnabled = false; # posthog is on by default
        embeddingModel = llama.alias;
      };
      # 2 slow cores: one page at a time, small embedding requests, long wait
      scraper = {
        maxConcurrency = 1;
        security.fileAccess.allowedRoots = [ filesMount ];
      };
      embeddings = {
        batchChars = 8000; # ~2k tokens per request instead of a whole page
        requestTimeoutMs = 600000;
      };
    }
    // lib.optionalAttrs (publicUrl != null) { server = { inherit publicUrl; }; }
  );

  environment = {
    # full names: the image sets HOST=0.0.0.0 and PORT, aliases beat the config file
    DOCS_MCP_SERVER_HOST = "127.0.0.1";
    DOCS_MCP_SERVER_PORTS_MCP = toString port;
    DOCS_MCP_CONFIG = "/etc/docs-mcp/config.json";
    OPENAI_API_BASE = "http://127.0.0.1:${toString llama.port}/v1";
    OPENAI_API_KEY = "none";
  }
  // lib.optionalAttrs (proxy != null) {
    # axios (all page fetches) reads these, llama-server stays direct
    HTTPS_PROXY = proxy;
    HTTP_PROXY = proxy;
    NO_PROXY = "127.0.0.1,localhost";
  };

  volumes = [
    "${dataDir}:/data"
    "${configFile}:/etc/docs-mcp/config.json:ro"
  ];

  cliArgs = [
    "--network=host"
    "--memory=1g"
    "-v"
    "${filesDir}:${filesMount}:ro"
  ]
  ++ lib.concatLists (
    lib.mapAttrsToList (k: v: [
      "-e"
      "${k}=${v}"
    ]) environment
  )
  ++ lib.concatMap (v: [
    "-v"
    v
  ]) volumes;

  # the cli in a throwaway container on the same store, it runs fine next to
  # the server. root only, like podman
  docs-mcp = pkgs.writeShellApplication {
    name = "docs-mcp";
    text = ''
      tty=()
      if [ -t 0 ] && [ -t 1 ]; then tty=(-it); fi
      # the sync units find their container by this label when they stop
      label=()
      if [ -n "''${DOCS_MCP_UNIT:-}" ]; then label=(--label "docs-mcp-unit=$DOCS_MCP_UNIT"); fi
      exec ${podman} run --rm --init "''${tty[@]}" "''${label[@]}" \
        -e LOG_LEVEL="''${LOG_LEVEL:-INFO}" ${lib.escapeShellArgs cliArgs} ${image} "$@"
    '';
  };

  # how each kind is scraped. the args are part of the key, so a change
  # here scrapes every source of that kind again
  fileArgs = name: [
    "file://${filesMount}/${name}"
    "--scrape-mode=fetch"
    # folders count as depth
    "--max-depth=50"
    "--max-pages=100000"
  ];
  entries =
    lib.mapAttrsToList (name: slug: {
      kind = "devdocs";
      inherit name slug;
      args = fileArgs name;
    }) sources.devdocs
    ++ lib.mapAttrsToList (name: path: {
      kind = "local";
      inherit name path;
      args = fileArgs name;
    }) sources.local
    ++ lib.mapAttrsToList (name: url: {
      kind = "github";
      inherit name;
      # tree/<branch>/<dir> finds its files as blob/..., outside that dir,
      # and the default subpages scope would drop every one of them
      args = [
        url
        "--scope=hostname"
      ];
    }) sources.github
    ++ lib.mapAttrsToList (name: url: {
      kind = "web";
      inherit name;
      args = [
        url
        "--scrape-mode=fetch"
        "--max-pages=1"
      ];
    }) sources.web;

  sourcesJson = pkgs.writeText "docs-mcp-sources.json" (
    builtins.toJSON (
      # devdocs adds its own mtime to the key at sync time, local changes
      # with the store path
      map (e: e // { key = builtins.hashString "sha256" (builtins.toJSON e); }) entries
    )
  );

  sync = pkgs.writeShellApplication {
    name = "docs-mcp-sync";
    runtimeInputs = [
      docs-mcp
      pkgs.curl
      pkgs.gnutar
      pkgs.gzip
      pkgs.jq
      pkgs.util-linux
    ];
    text = builtins.readFile ./sync.sh;
  };

  syncService = mode: {
    wants = [ "podman-docs-mcp.service" ];
    after = [
      "podman-docs-mcp.service"
      "xray.service"
    ];
    # a first scrape takes hours, a restart on switch would wait for it.
    # the timers start these instead
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getExe sync} ${sourcesJson} ${mode}";
      StateDirectory = "docs-mcp-sync";
      # podman can't pass a stop on to the container from inside the unit
      # (systemd kills its crun too), so kill the script and stop the
      # container by its label
      KillMode = "mixed";
      ExecStopPost = "-${podman} stop --filter label=docs-mcp-unit=docs-mcp-${mode}";
    };
    environment = {
      DOCS_MCP_UNIT = "docs-mcp-${mode}";
      DOCS_MCP_FILES = filesDir;
    }
    # devdocs downloads go through xray too
    // lib.optionalAttrs (proxy != null) { https_proxy = proxy; };
  };
in
{
  assertions = [
    {
      assertion = lib.allUnique (map (e: e.name) entries);
      message = "docs-mcp/sources.nix: names must be unique";
    }
  ];

  # the image runs as uid 1000
  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 1000 1000 -"
    # the cli mounts it, so it has to exist before the first sync
    "d ${filesDir} 0755 root root -"
  ];

  environment.systemPackages = [ docs-mcp ];

  virtualisation.oci-containers.containers.docs-mcp = {
    inherit image environment volumes;
    # only /mcp, no web ui or api. read-only: search tools only, an agent
    # can't start a scrape, and the server runs no jobs
    cmd = [
      "mcp"
      "--read-only"
    ];
    extraOptions = [
      "--network=host"
      "--memory=768m"
      # node is pid 1 in the image and ignores SIGTERM, catatonit passes it on
      "--init"
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

  # scrape new and changed sources, remove dropped ones
  systemd.services.docs-mcp-sync = syncService "sync";
  systemd.timers.docs-mcp-sync = {
    wantedBy = [ "timers.target" ];
    # a minute after boot or a sources.nix change, then daily for failed ones
    restartTriggers = [ sourcesJson ];
    timerConfig = {
      OnActiveSec = "1min";
      OnUnitInactiveSec = "1d";
    };
  };

  # pick up upstream doc changes, unchanged pages are skipped
  systemd.services.docs-mcp-refresh = syncService "refresh";
  systemd.timers.docs-mcp-refresh = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
