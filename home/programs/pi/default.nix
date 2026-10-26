{
  config,
  pkgs,
  lib,
  osConfig ? { },
  ...
}:
let
  llamaSwapHost = "http://localhost:11434";
  searxngUrl = "http://127.0.0.1:11433";
  docsMcpUrl = "http://127.0.0.1:6280/mcp";

  # the docs index runs on barnard only (nixos/services/docs-mcp)
  hasDocs = osConfig.virtualisation.oci-containers.containers or { } ? docs-mcp;
  # names only, so the skill knows what's there without asking
  docsSources = import ../../../nixos/services/docs-mcp/sources.nix {
    inherit pkgs;
    config = osConfig;
  };
  docsLibraries = lib.concatStringsSep ", " (
    lib.sort lib.lessThan (lib.concatMap builtins.attrNames (builtins.attrValues docsSources))
  );

  # Thinking per model family. llama-swap starts each model with its own
  # sampling defaults, pi only sends what a thinking level changes.
  families = {
    qwen = {
      # the template knows low, medium and xhigh (its default)
      thinkingLevelMap = {
        minimal = null;
        high = "xhigh";
      };
      chatTemplateKwargs = {
        enable_thinking."$var" = "thinking.enabled";
        reasoning_effort = {
          "$var" = "thinking.effort";
          omitWhenOff = true;
        };
        # else the template drops old thinking after each user message, the
        # prompt changes and llama.cpp re-reads it from that point
        preserve_thinking = true;
      };
      # Qwen's non-thinking values
      off = {
        temperature = 0.7;
        top_p = 0.8;
        presence_penalty = 1.5;
      };
    };

    # the template is on/off only
    gemma = {
      thinkingLevelMap = {
        minimal = null;
        low = null;
        high = null;
      };
      chatTemplateKwargs.enable_thinking."$var" = "thinking.enabled";
    };

    # reasoning_effort low | medium | high, can't stop thinking
    gpt-oss = {
      thinkingLevelMap = {
        off = null;
        minimal = null;
      };
      chatTemplateKwargs.reasoning_effort."$var" = "thinking.effort";
    };
  };

  mkModel =
    {
      id,
      name,
      family,
      ctx,
      vision ? false, # only for models started with --mmproj
    }:
    let
      fam = families.${family};
    in
    {
      inherit id name;
      input = [ "text" ] ++ lib.optional vision "image";
      contextWindow = ctx;
      # thinking and the answer share it
      maxTokens = ctx / 2;
      reasoning = true;
      inherit (fam) thinkingLevelMap;
      compat.chatTemplateKwargs = fam.chatTemplateKwargs;
    }
    // lib.optionalAttrs (fam.thinkingLevelMap.off or "" != null) {
      # budget 0: llama-server closes a <think> the model opens anyway.
      # The other levels have no cap, reasoning_effort only asks
      # the model to think less or more
      samplingParamsByThinkingLevel.off = (fam.off or { }) // {
        thinking_budget_tokens = 0;
      };
    };

  # ctx = --ctx-size in nixos/services/llama-swap/config.yaml
  models = map mkModel [
    {
      id = "qwen";
      name = "Qwen3.8 27B";
      family = "qwen";
      ctx = 131072;
    }
    {
      id = "qwen-uncensored";
      name = "Qwen3.8 27B uncensored";
      family = "qwen";
      ctx = 131072;
    }
    {
      id = "qwen-uncensored-vision";
      name = "Qwen3.8 27B uncensored vision";
      family = "qwen";
      ctx = 65536;
      vision = true;
    }
    {
      id = "gemma-26b";
      name = "Gemma 4 26B-A4B";
      family = "gemma";
      ctx = 131072;
    }
    {
      id = "gemma-12b";
      name = "Gemma 4 12B";
      family = "gemma";
      ctx = 131072;
    }
    {
      id = "gpt-oss";
      name = "gpt-oss 20B";
      family = "gpt-oss";
      ctx = 131072;
    }
  ];

  piModels = {
    providers.llama-swap = {
      name = "llama-swap";
      baseUrl = "${llamaSwapHost}/v1";
      api = "openai-completions";
      apiKey = "none"; # required even though llama-swap ignores it
      compat = {
        supportsDeveloperRole = false;
        thinkingFormat = "chat-template";
      };
      inherit models;
    };
  };

  piSettings = {
    defaultProvider = "llama-swap";
    defaultModel = "qwen";
    defaultThinkingLevel = "low";
    # Pinned: extensions run with full user rights, and pi-permission-system
    # ships breaking majors. Bump by hand after reading the changelog.
    packages = [
      "npm:pi-web-access@0.44.0"
      # "npm:@samfp/pi-memory@1.6.1"
      "npm:@juicesharp/rpiv-todo@2.13.10"
      # "npm:@gotgenes/pi-permission-system@41.0.0"
      "npm:@juicesharp/rpiv-ask-user-question@2.13.10"
    ];
    # memory = {
    #   # Passed verbatim to `pi --model`; trailing ":off" is the thinking level.
    #   # The whole run has a hard 45 s timeout and fails silently, so keep
    #   # this a small, fast, fully-on-GPU model. It runs at session end and
    #   # swaps the main model out of VRAM (same llama-swap group).
    #   consolidationModel = "llama-swap/gemma-12b:off";
    #   # One memory dump at session start instead of a new block every turn.
    #   # The per-turn block is not kept in history, so each new turn would
    #   # make llama.cpp re-process the whole previous turn.
    #   perTurnInjection = false;
    #   # Hybrid search for the memory_search tool via the always-loaded
    #   # CPU embedding model. pi-memory appends /v1/embeddings itself.
    #   embedding = {
    #     type = "openai-compatible";
    #     baseUrl = llamaSwapHost;
    #     model = "embed";
    #     # EmbeddingGemma 2 output width. A mismatch makes pi-memory re-embed
    #     # every stored fact at each session start.
    #     dimensions = 768;
    #   };
    # };
  };

  # pi-web-access config (~/.pi/web-search.json)
  webSearch = {
    searxngBaseUrl = searxngUrl;
    # Strict: only SearXNG. With "auto" it silently falls back to Exa etc.
    # A loopback searxngBaseUrl passes the SSRF guard on its own, no
    # ssrf.allowRanges: that would let fetch_content reach every local
    # service (llama-swap's api too) from a prompt-injected page.
    provider = "searxng";
    # Raw results straight to the model, no curator window or summary model
    workflow = "none";
    # Not needed without Gemini keys; avoids pointless fallback attempts
    youtube.enabled = false;
    video.enabled = false;
  };

  # pi's built-in MCP client. direct: the tools are declared like built-in
  # ones, a local model calls them more reliably than through codemode
  # scripts. fetch_url is hidden, pi-web-access's fetch_content does that
  piMcp.mcpServers = lib.optionalAttrs hasDocs {
    docs = {
      url = docsMcpUrl;
      description = "Search the local documentation index: ${docsLibraries}";
      exposure = "direct";
      toolExposure.fetch_url = "hidden";
      # embedding the query waits for embed while it's busy with a sync
      timeout = 120;
    };
  };

  docsSkill = pkgs.writeTextDir "SKILL.md" ''
    ---
    name: docs
    description: Search the local documentation index for ${docsLibraries}. Use before answering about or writing code for any of these, and instead of web search for them.
    ---

    # Local docs index

    The `mcp__docs__*` tools search documentation indexed on this machine:
    ${docsLibraries}. It's faster and more exact than web search for these.

    ## Steps

    1. `mcp__docs__search_docs` with `library` (a name above) and a short
       English `query` worded the way the docs would say it: option, function
       or flag names, not a question. `limit` 5 to 10.
    2. Each result is a passage with its page `url`. When a passage is cut
       short or you need the whole section, call `mcp__docs__read_page` with
       that url as `pathOrUrl`.
    3. Nothing useful: rephrase once with other terms, or try the related
       library: nixos-manual for NixOS options and modules, nix-manual for
       the nix CLI and language, nixpkgs-manual for builders, fetchers and
       overrides, nix-dev for tutorials.
    4. Still nothing: say so, then use web search.

    ## Rules

    - `mcp__docs__list_libraries` shows everything indexed, also libraries
      added by hand.
    - Answer from the passages and name the page url.
    - Don't make up option names or flags the docs didn't show.
  '';

  # pi writes settings.json and mcp.json itself (/model and /thinking
  # Ctrl+S, lastChangelogVersion, /mcp exposure), a store symlink makes
  # every write fail. So they're real files: nix keys are merged over them
  # on each switch and win, the rest of what pi saved stays.
  piSettingsFile = pkgs.writeText "pi-settings.json" (builtins.toJSON piSettings);
  piMcpFile = pkgs.writeText "pi-mcp.json" (builtins.toJSON piMcp);

  jq = lib.getExe pkgs.jq;
  mergeJson = name: file: ''
    f=${config.home.homeDirectory}/.pi/agent/${name}
    run mkdir -p "$(dirname "$f")"
    if [ -L "$f" ]; then run rm "$f"; fi
    if [ -s "$f" ] && ${jq} -e . "$f" >/dev/null 2>&1; then
      tmp=$(mktemp)
      ${jq} -s '.[0] * .[1]' "$f" ${file} >"$tmp"
      run mv "$tmp" "$f"
    else
      run install -m 644 ${file} "$f"
    fi
  '';

  # ~/.local/share/pi/npm instead of the read-only store, node available.
  # Done without an overlay so it works with home-manager.useGlobalPkgs = true.
  pi = pkgs.symlinkJoin {
    name = "pi-coding-agent-wrapped";
    paths = [ pkgs.pi-coding-agent ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/pi \
        --set PI_TELEMETRY 0 \
        --set NPM_CONFIG_PREFIX ${config.xdg.dataHome}/pi/npm/ \
        --prefix PATH : ${lib.makeBinPath [ pkgs.nodejs_latest ]}
    '';
  };
in
{
  imports = [
    ./qmd.nix
  ];

  home.packages = [
    pi
    pkgs.python3Packages.huggingface-hub
  ];

  home.file = {
    ".pi/agent/models.json".text = builtins.toJSON piModels;
    ".pi/web-search.json".text = builtins.toJSON webSearch;
    # Kept as a literal JSON file: rules are last-match-wins and
    # builtins.toJSON would sort the keys alphabetically.
    # ".pi/agent/extensions/pi-permission-system/config.json".source = ./pi-permission.json;
    ".pi/agent/skills" = {
      source = ./pi-skills;
      recursive = true;
    };
  }
  // lib.optionalAttrs hasDocs {
    ".pi/agent/skills/docs".source = docsSkill;
  };

  # after linkGeneration, so an old store symlink is already gone
  home.activation.piSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    mergeJson "settings.json" piSettingsFile + mergeJson "mcp.json" piMcpFile
  );
}
