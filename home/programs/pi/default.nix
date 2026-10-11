{
  config,
  pkgs,
  lib,
  ...
}:
let
  llamaSwapHost = "http://localhost:11434";
  searxngUrl = "http://127.0.0.1:11433";

  families = {
    qwen = {
      thinkingLevelMap = {
        off = "none";
        minimal = null;
        low = "low";
        medium = "medium";
        high = "xhigh";
      };
      chatTemplateKwargs = {
        enable_thinking."$var" = "thinking.enabled";
        reasoning_effort."$var" = "thinking.effort";
      };
    };

    # Gemma 4 template is on/off only, so expose just "off" and "low".
    gemma = {
      thinkingLevelMap = {
        minimal = null;
        medium = null;
        high = null;
      };
      chatTemplateKwargs.enable_thinking."$var" = "thinking.enabled";
    };

    # gpt-oss takes reasoning_effort = low | medium | high and cannot stop
    # thinking, so "off" is hidden. low/medium/high pass through unchanged.
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
      ctx,
      family ? null, # null = no pi-controlled thinking
      vision ? false, # true only for entries started with --mmproj
    }:
    {
      inherit id name;
      input = [ "text" ] ++ lib.optional vision "image";
      contextWindow = ctx;
      maxTokens = lib.min 32768 (ctx / 2);
      reasoning = family != null;
    }
    // lib.optionalAttrs (family != null) {
      inherit (families.${family}) thinkingLevelMap;
      compat.chatTemplateKwargs = families.${family}.chatTemplateKwargs;
    };

  mkPiModel = m: mkModel (m // { id = "${m.id}:pi"; });

  models =
    map mkPiModel [
      {
        id = "qwen-code";
        name = "Qwen 27B Q4 code";
        ctx = 131072;
        family = "qwen";
      }
      {
        id = "qwen-smart";
        name = "Qwen 27B Q6 smart";
        ctx = 65536;
        family = "qwen";
      }
      {
        id = "qwen-fast";
        name = "Qwen 27B Q3 fast";
        ctx = 32768;
        family = "qwen";
      }
      {
        id = "qwen-uncensored";
        name = "Qwen 27B IQ3 uncensored";
        ctx = 98304;
        family = "qwen";
      }
      {
        id = "qwen-uncensored-vision";
        name = "Qwen 27B IQ3 uncensored vision";
        ctx = 65536;
        family = "qwen";
        vision = true;
      }
      {
        id = "gpt-oss";
        name = "gpt-oss 20B";
        ctx = 65536;
        family = "gpt-oss";
      }
      {
        id = "gemma-26b";
        name = "Gemma 4 26B-A4B";
        ctx = 65536;
        family = "gemma";
      }
      {
        id = "gemma-12b";
        name = "Gemma 4 12B";
        ctx = 65536;
        family = "gemma";
      }
    ]
    ++ [
      # Thinking is fixed server-side for this one
      (mkModel {
        id = "Qwen-Benchmark";
        name = "Qwen 27B IQ3_XXS benchmark";
        ctx = 32768;
      })
    ];

  piModels = {
    providers.llama-swap = {
      name = "llama-swap";
      baseUrl = "${llamaSwapHost}/v1";
      api = "openai-completions";
      apiKey = "none"; # required even though llama-swap ignores it
      compat = {
        supportsDeveloperRole = false;
        supportsReasoningEffort = false;
        # chat_template_kwargs come from each model's compat.chatTemplateKwargs
        thinkingFormat = "chat-template";
      };
      inherit models;
    };
  };

  piSettings = {
    defaultProvider = "llama-swap";
    defaultModel = "qwen-code:pi";
    defaultThinkingLevel = "low";
    packages = [
      "npm:pi-web-access"
      "npm:@samfp/pi-memory"
      "npm:@juicesharp/rpiv-todo"
      "npm:@gotgenes/pi-permission-system"
      "npm:@juicesharp/rpiv-ask-user-question"
    ];
    memory = {
      # Passed verbatim to `pi --model`; trailing ":off" is the thinking level.
      # The whole run has a hard 45 s timeout and fails silently, so keep
      # this a small, fast, fully-on-GPU model.
      consolidationModel = "llama-swap/gemma-12b:pi:off";
      # One memory dump at session start instead of a new block every turn.
      # The per-turn block is not kept in history, so each new turn would
      # make llama.cpp re-process the whole previous turn.
      perTurnInjection = false;
      # Hybrid search for the memory_search tool via the always-loaded
      # CPU embedding model. pi-memory appends /v1/embeddings itself.
      embedding = {
        type = "openai-compatible";
        baseUrl = llamaSwapHost;
        model = "embed";
        dimensions = 1024; # Qwen3-Embedding-0.6B output width
      };
    };
  };

  # pi-web-access config (~/.pi/web-search.json)
  webSearch = {
    searxngBaseUrl = searxngUrl;
    # Strict: only SearXNG. With "auto" it silently falls back to Exa etc.
    provider = "searxng";
    # Raw results straight to the model. The default curator opens a browser
    # window and drafts summaries with a separate model.
    workflow = "none";
    # SSRF guard blocks loopback by default; allow only localhost for SearXNG
    ssrf.allowRanges = [ "127.0.0.1/32" ];
    # Not needed without Gemini keys; avoids pointless fallback attempts
    youtube.enabled = false;
    video.enabled = false;
  };

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
    ".pi/agent/settings.json".text = builtins.toJSON piSettings;
    ".pi/web-search.json".text = builtins.toJSON webSearch;
    # Kept as a literal JSON file: rules are last-match-wins and
    # builtins.toJSON would sort the keys alphabetically.
    ".pi/agent/extensions/pi-permission-system/config.json".source = ./pi-permission.json;
    ".pi/agent/skills" = {
      source = ./pi-skills;
      recursive = true;
    };
  };
}
