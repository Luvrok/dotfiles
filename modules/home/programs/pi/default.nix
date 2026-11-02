{
  config,
  pkgs,
  lib,
  ...
}:
let
  # npm prefix outside the read-only store and node for packages, no overlay so useGlobalPkgs works
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

  # contextWindow in models.json repeats --ctx-size from
  # modules/nixos/llama-swap/config.yaml, change both. the packages in
  # settings.json are pinned: extensions run with the user's rights
  home.file = {
    ".pi/agent/models.json".source = ./models.json;
    ".pi/agent/AGENTS.md".source = ./AGENTS.md;
    ".pi/web-search.json".source = ./web-search.json;
    ".pi/agent/extensions/pi-permission-system/config.json".source =
      ./extensions/pi-permission-system/config.json;
    ".pi/agent/skills/obsidian".source = ./skills/obsidian;
    ".pi/agent/skills/qwen-generate".source = ./skills/qwen-generate;
  };

  # pi writes these itself (/model, /thinking, /mcp, lastChangelogVersion),
  # so they are copies, not store links. every switch puts the repo's back
  home.activation.piConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    run mkdir -p "$HOME/.pi/agent"
    for f in settings.json mcp.json; do
      run rm -f "$HOME/.pi/agent/$f"
    done
    run install -m 644 ${./settings.json} "$HOME/.pi/agent/settings.json"
    run install -m 644 ${./mcp.json} "$HOME/.pi/agent/mcp.json"
  '';
}
