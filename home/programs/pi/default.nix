{
  config,
  pkgs,
  lib,
  ...
}:
let
  repo = "${config.home.homeDirectory}/HOME/infra/dotfiles/pi";
  inherit (config.lib.file) mkOutOfStoreSymlink;

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
  imports = [
    ./qmd.nix
  ];

  home.packages = [
    pi
    pkgs.python3Packages.huggingface-hub
  ];

  # out of store: pi writes settings.json and mcp.json itself, a store file is read-only
  home.file = {
    ".pi/agent/settings.json".source = mkOutOfStoreSymlink "${repo}/settings.json";
    ".pi/agent/models.json".source = mkOutOfStoreSymlink "${repo}/models.json";
    ".pi/agent/mcp.json".source = mkOutOfStoreSymlink "${repo}/mcp.json";
    ".pi/web-search.json".source = mkOutOfStoreSymlink "${repo}/web-search.json";
    ".pi/agent/extensions/pi-permission-system/config.json".source =
      mkOutOfStoreSymlink "${repo}/extensions/pi-permission-system/config.json";
    # one link per skill, qmd.nix puts its own skill in the same dir
    ".pi/agent/skills/docs".source = mkOutOfStoreSymlink "${repo}/skills/docs";
    ".pi/agent/skills/qwen-generate".source = mkOutOfStoreSymlink "${repo}/skills/qwen-generate";
  };
}
