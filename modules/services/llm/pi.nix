# home-manager module: pi coding agent wired to llama-swap and SearXNG.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  llamaSwapUrl = "http://localhost:11434/v1";
  searxngUrl = "http://127.0.0.1:11433";

  mkModel =
    {
      id,
      name,
      ctx,
      thinking ? false,
    }:
    {
      inherit id name;
      reasoning = thinking;
      contextWindow = ctx;
      maxTokens = if thinking then 32768 else 16384;
    };

  bases = [
    {
      id = "qwen-fast";
      name = "Qwen 27B Q3 fast";
      ctx = 32768;
    }
    {
      id = "qwen-code";
      name = "Qwen 27B Q4 code";
      ctx = 131072;
    }
    {
      id = "qwen-smart";
      name = "Qwen 27B Q6 smart";
      ctx = 65536;
    }
  ];

  variants = [
    {
      suffix = "";
      label = "chat";
      thinking = false;
    }
    {
      suffix = ":Thinking";
      label = "chat + thinking";
      thinking = true;
    }
    {
      suffix = ":Coding";
      label = "code";
      thinking = false;
    }
    {
      suffix = ":Thinking Coding";
      label = "code + thinking";
      thinking = true;
    }
  ];

  models = lib.concatMap (
    b:
    map (
      v:
      mkModel {
        id = b.id + v.suffix;
        name = "${b.name} · ${v.label}";
        inherit (b) ctx;
        inherit (v) thinking;
      }
    ) variants
  ) bases;

  piModels = {
    providers.llama-swap = {
      name = "llama-swap";
      baseUrl = llamaSwapUrl;
      api = "openai-completions";
      apiKey = "none"; # required even though llama-swap ignores it
      compat = {
        supportsDeveloperRole = false;
        supportsReasoningEffort = false; # thinking is switched by alias, not reasoning_effort
      };
      inherit models;
    };
  };

  piSettings = {
    defaultProvider = "llama-swap";
    defaultModel = "qwen-code:Coding";
    packages = [ "npm:pi-web-access" ];
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
  home.packages = [
    pi
    pkgs.python3Packages.huggingface-hub
  ];

  home.file.".pi/agent/models.json".text = builtins.toJSON piModels;
  home.file.".pi/agent/settings.json".text = builtins.toJSON piSettings;
  home.file.".pi/web-search.json".text = builtins.toJSON webSearch;
}
