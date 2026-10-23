{
  config,
  pkgs,
  lib,
  ...
}:
let
  llamaSwapHost = "http://localhost:11434";
  searxngUrl = "http://127.0.0.1:11433";

  # Qwen3.8 sampling per thinking level (official Qwen / Unsloth values).
  # llama-swap forces top_k and min_p, the :pi alias leaves the rest to pi.
  # Thinking temp 1.0 is meant for code too on 3.8, 0.6 was 3.5/3.6 advice.
  qwenThinking = {
    temperature = 1.0;
    top_p = 0.95;
    presence_penalty = 0.0;
  };
  qwenInstruct = {
    temperature = 0.7;
    top_p = 0.8;
    presence_penalty = 1.5;
  };

  families = {
    qwen = {
      samplingParams = qwenThinking;
      samplingParamsByThinkingLevel.off = qwenInstruct;
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
      sampling ? { }, # merged over the family's samplingParams
    }:
    let
      fam = families.${family};
    in
    {
      inherit id name;
      input = [ "text" ] ++ lib.optional vision "image";
      contextWindow = ctx;
      maxTokens = lib.min 32768 (ctx / 2);
      reasoning = family != null;
    }
    // lib.optionalAttrs (family != null) (
      {
        inherit (fam) thinkingLevelMap;
        compat.chatTemplateKwargs = fam.chatTemplateKwargs;
      }
      // lib.optionalAttrs (fam ? samplingParams || sampling != { }) {
        samplingParams = (fam.samplingParams or { }) // sampling;
      }
      // lib.optionalAttrs (fam ? samplingParamsByThinkingLevel) {
        inherit (fam) samplingParamsByThinkingLevel;
      }
    );

  mkPiModel = m: mkModel (m // { id = "${m.id}:pi"; });

  # The GSQ quant's card asks for temp 0.6 for reliable tool calls
  gsqSampling.temperature = 0.6;

  # ctx must match --ctx-size in nixos/services/llama-swap/config.yaml
  models =
    map mkPiModel [
      {
        id = "qwen-fast";
        name = "Qwen 27B Q3 fast";
        ctx = 65536;
        family = "qwen";
      }
      {
        id = "qwen-uncensored";
        name = "Qwen 27B IQ3 uncensored";
        ctx = 65536;
        family = "qwen";
        sampling = gsqSampling;
      }
      {
        id = "qwen-uncensored-vision";
        name = "Qwen 27B IQ3 uncensored vision";
        ctx = 65536;
        family = "qwen";
        vision = true;
        sampling = gsqSampling;
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
    defaultModel = "qwen-fast:pi";
    defaultThinkingLevel = "low";
    # Pinned: extensions run with full user rights, and pi-permission-system
    # ships breaking majors. Bump by hand after reading the changelog.
    packages = [
      "npm:pi-web-access@0.44.0"
      "npm:@samfp/pi-memory@1.6.1"
      "npm:@juicesharp/rpiv-todo@2.13.10"
      "npm:@gotgenes/pi-permission-system@41.0.0"
      "npm:@juicesharp/rpiv-ask-user-question@2.13.10"
    ];
    memory = {
      # Passed verbatim to `pi --model`; trailing ":off" is the thinking level.
      # The whole run has a hard 45 s timeout and fails silently, so keep
      # this a small, fast, fully-on-GPU model. It runs at session end and
      # swaps the main model out of VRAM (same llama-swap group).
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
        # EmbeddingGemma 2 output width. A mismatch makes pi-memory re-embed
        # every stored fact at each session start.
        dimensions = 768;
      };
    };
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

  # pi writes settings.json itself (/model and /thinking Ctrl+S,
  # lastChangelogVersion), a store symlink makes every write fail. So it's a
  # real file: nix keys are merged over it on each switch and win, the rest
  # of what pi saved stays.
  piSettingsFile = pkgs.writeText "pi-settings.json" (builtins.toJSON piSettings);

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
    ".pi/agent/extensions/pi-permission-system/config.json".source = ./pi-permission.json;
    ".pi/agent/skills" = {
      source = ./pi-skills;
      recursive = true;
    };
  };

  # after linkGeneration, so the old store symlink is already gone
  home.activation.piSettings = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    f=${config.home.homeDirectory}/.pi/agent/settings.json
    run mkdir -p "$(dirname "$f")"
    if [ -L "$f" ]; then run rm "$f"; fi
    if [ -s "$f" ] && ${lib.getExe pkgs.jq} -e . "$f" >/dev/null 2>&1; then
      tmp=$(mktemp)
      ${lib.getExe pkgs.jq} -s '.[0] * .[1]' "$f" ${piSettingsFile} >"$tmp"
      run mv "$tmp" "$f"
    else
      run install -m 644 ${piSettingsFile} "$f"
    fi
  '';
}
