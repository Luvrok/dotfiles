# notes-mcp: the obsidian vault in its own docs-mcp-server, apart from the
# docs index (../docs-mcp): its own container, port and database, the same
# image and the same vectors from llama-swap's embed (embeddinggemma-2, on
# the cpu). read-only search over MCP for pi (modules/home/programs/pi).
# the vault is scraped as libraries: a full scrape when a library's args
# change, else a refresh every 30 min that skips unchanged notes.
# needs llama-swap, so a desktop host (modules/nixos/desktop)
{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  cfg = config.dotfiles.notes-mcp;
  port = 6281;
  dataDir = "/var/lib/notes-mcp";
  vault = "/home/${username}/HOME/wizzard/Holocron";
  # the vault inside the containers
  mount = "/notes";
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
  # one between slashes, no flags after them. hidden files and folders
  # (.obsidian, .trash, .anything) docs-mcp skips by itself, includeHidden
  # is off by default
  commonArgs = [
    "--scrape-mode=fetch"
    "--max-depth=50"
    "--max-pages=100000"
    "--exclude-pattern=/\\.(?!md$)[A-Za-z0-9]{1,8}$/"
    "--exclude-pattern=**/copilot"
    "--exclude-pattern=**/copilot/**"
    "--exclude-pattern=**/_meta"
    "--exclude-pattern=**/_meta/**"
  ];

  # docs-mcp scopes a search by library and never by path, so what has to rank
  # on its own gets its own library: notes are the human's notes, self is
  # memory/ (the agent's memory and journal), wiki is the wiki the agent keeps
  argsFor = sub: extra: [ "file://${mount}${sub}" ] ++ commonArgs ++ extra;

  libraries = {
    notes = argsFor "" [
      # memory/ has its own library, a note would compete with a memory page
      "--exclude-pattern=**/memory"
      "--exclude-pattern=**/memory/**"
      # the template is not a note
      "--exclude-pattern=**/8-templates"
      "--exclude-pattern=**/8-templates/**"
    ];
    self = argsFor "/memory" [
      "--exclude-pattern=**/wiki"
      "--exclude-pattern=**/wiki/**"
    ];
    wiki = argsFor "/memory/wiki" [
      # generated on every join, read by path, not worth re-embedding
      "--exclude-pattern=**/index.md"
    ];
  };
  # per library, so changing the wiki leaves the notes index alone
  keys = lib.mapAttrs (_: args: builtins.hashString "sha256" (builtins.toJSON args)) libraries;

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

  syncSteps = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (
      name: args: "sync_one ${name} ${keys.${name}} ${lib.escapeShellArgs args}"
    ) libraries
  );

  sync = pkgs.writeShellApplication {
    name = "notes-mcp-sync";
    runtimeInputs = [
      notes-mcp
      pkgs.jq
      pkgs.coreutils
    ];
    text = ''
      state=''${STATE_DIRECTORY:-/var/lib/notes-mcp-sync}/keys
      mkdir -p "$state"
      existing=$(LOG_LEVEL=ERROR notes-mcp list </dev/null | jq -r '.[].name')

      sync_one() {
        name=$1
        key=$2
        shift 2
        if grep -qxF "$name" <<<"$existing" && [ "$(cat "$state/$name" 2>/dev/null)" = "$key" ]; then
          echo "refreshing $name"
          notes-mcp refresh "$name" </dev/null
        else
          echo "scraping $name"
          notes-mcp scrape "$name" "$@" --replace </dev/null
          echo "$key" >"$state/$name"
        fi
      }

      ${syncSteps}
    '';
  };
in
{
  options.dotfiles.notes-mcp.enable = lib.mkEnableOption "the obsidian vault's mcp index";

  config = lib.mkIf cfg.enable {
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
      restartTriggers = [ (builtins.hashString "sha256" (builtins.toJSON libraries)) ];
      timerConfig = {
        OnActiveSec = "2min";
        OnUnitInactiveSec = "30min";
      };
    };
  };
}
