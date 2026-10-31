# notes-mcp: the obsidian vault in its own docs-mcp-server, apart from the
# docs index (../docs-mcp): its own container, port and database, the same
# image and the same vectors from llama-swap's embed (embeddinggemma-2, on
# the cpu). read-only search over MCP for pi (pi/mcp.json, the notes skill).
# the vault is scraped as one library, "notes": a full scrape when the
# scrape args change, else a refresh every 30 min that skips unchanged notes.
# barnard only, its env.nix imports this
{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  port = 6281;
  dataDir = "/var/lib/notes-mcp";
  vault = "/home/${username}/HOME/wizzard/Holocron";
  # the vault inside the containers
  mount = "/notes";
  library = "notes";
  # the same as ../docs-mcp, no latest: a new release can migrate the db
  image = "ghcr.io/arabold/docs-mcp-server:3.3.0";
  llamaSwap = "http://127.0.0.1:${toString config.services.llama-swap.port}";
  # an alias of embed in llama-swap/config.yaml, the index is keyed on it
  embeddingModel = "embeddinggemma-2-bf16";
  podman = lib.getExe config.virtualisation.podman.package;

  configFile = (pkgs.formats.json { }).generate "notes-mcp.json" {
    app = {
      telemetryEnabled = false;
      inherit embeddingModel;
    };
    scraper.security.fileAccess.allowedRoots = [ mount ];
    # embed is one llama-server, docs-mcp and pi-memory use it too
    embeddings.requestTimeoutMs = 300000;
  };

  environment = {
    DOCS_MCP_SERVER_HOST = "127.0.0.1";
    DOCS_MCP_SERVER_PORTS_MCP = toString port;
    DOCS_MCP_CONFIG = "/etc/docs-mcp/config.json";
    OPENAI_API_BASE = "${llamaSwap}/v1";
    OPENAI_API_KEY = "none";
  };

  # the server too: read_page may read a note from its file:// url
  volumes = [
    "${dataDir}:/data"
    "${configFile}:/etc/docs-mcp/config.json:ro"
    "${vault}:${mount}:ro"
  ];

  # notes only, nothing of obsidian's own. an exclude replaces docs-mcp's
  # default ones (changelogs, tests, archive...), they'd drop real notes.
  # no include: docs-mcp filters the folders it walks with it too, **/*.md
  # left it at the vault's root. so every name with an extension but .md
  # is out (pictures, pdfs, canvases), folders have none. a regex is only
  # one between slashes, no flags after them. hidden ones
  # (.obsidian, .trash) docs-mcp skips by itself
  scrapeArgs = [
    "file://${mount}"
    "--scrape-mode=fetch"
    "--max-depth=50"
    "--max-pages=100000"
    "--exclude-pattern=/\\.(?!md$)[A-Za-z0-9]{1,8}$/"
    "--exclude-pattern=**/copilot/**"
  ];
  # a change here scrapes the whole vault again
  scrapeKey = builtins.hashString "sha256" (builtins.toJSON scrapeArgs);

  cliArgs = [
    "--network=host"
    "--memory=2g"
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

  # the cli in a throwaway container on the same store, root only like podman
  notes-mcp = pkgs.writeShellApplication {
    name = "notes-mcp";
    text = ''
      tty=()
      if [ -t 0 ] && [ -t 1 ]; then tty=(-it); fi
      exec ${podman} run --rm --init "''${tty[@]}" --label notes-mcp-unit=notes-mcp-sync \
        -e LOG_LEVEL="''${LOG_LEVEL:-INFO}" ${lib.escapeShellArgs cliArgs} ${image} "$@"
    '';
  };

  sync = pkgs.writeShellApplication {
    name = "notes-mcp-sync";
    runtimeInputs = [
      notes-mcp
      pkgs.jq
    ];
    text = ''
      state=''${STATE_DIRECTORY:-/var/lib/notes-mcp-sync}/key
      existing=$(LOG_LEVEL=ERROR notes-mcp list </dev/null | jq -r '.[].name')
      if grep -qxF ${library} <<<"$existing" && [ "$(cat "$state" 2>/dev/null)" = ${scrapeKey} ]; then
        echo "refreshing ${library}"
        exec notes-mcp refresh ${library} </dev/null
      fi
      echo "scraping ${library}"
      notes-mcp scrape ${library} ${lib.escapeShellArgs scrapeArgs} --replace </dev/null
      echo ${scrapeKey} >"$state"
    '';
  };
in
{
  # the image runs as uid 1000, the vault's owner reads it the same
  systemd.tmpfiles.rules = [ "d ${dataDir} 0750 1000 1000 -" ];

  environment.systemPackages = [ notes-mcp ];

  virtualisation.oci-containers.containers.notes-mcp = {
    inherit image environment volumes;
    # only /mcp, search tools only, an agent can't start a scrape
    cmd = [
      "mcp"
      "--read-only"
    ];
    extraOptions = [
      "--network=host"
      "--memory=1g"
      "--init"
    ];
  };

  systemd.services.podman-notes-mcp = {
    wants = [ "llama-swap.service" ];
    after = [ "llama-swap.service" ];
    # the first start asks embed for its vector size, this waits for it
    serviceConfig.ExecStartPre = lib.mkAfter [
      "${lib.getExe pkgs.curl} -sf -o /dev/null --retry 30 --retry-delay 2 --retry-all-errors ${llamaSwap}/upstream/${embeddingModel}/health"
    ];
  };

  systemd.services.notes-mcp-sync = {
    wants = [ "podman-notes-mcp.service" ];
    after = [ "podman-notes-mcp.service" ];
    restartIfChanged = false;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe sync;
      StateDirectory = "notes-mcp-sync";
      KillMode = "mixed";
      ExecStopPost = "-${podman} stop --filter label=notes-mcp-unit=notes-mcp-sync";
      Nice = 10;
    };
  };
  systemd.timers.notes-mcp-sync = {
    wantedBy = [ "timers.target" ];
    restartTriggers = [ scrapeKey ];
    timerConfig = {
      OnActiveSec = "2min";
      OnUnitInactiveSec = "30min";
    };
  };
}
