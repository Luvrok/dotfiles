{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  repo = ../../../opencode;

  # all of opencode through xray (127.0.0.1:10808): gemini answers "user
  # location is not supported" to a direct request. its bash commands get
  # the same env, as pi's shellCommandPrefix. loopback stays direct for docs
  # and searxng. lsp servers and formatters come from nixos/packages.nix, a
  # downloaded binary doesn't run on nixos
  proxy = "http://127.0.0.1:10808";
  noProxy = "localhost,127.0.0.1,::1";
  opencode = pkgs.symlinkJoin {
    name = "opencode-wrapped";
    paths = [ pkgs.opencode ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/opencode \
        ${lib.concatMapStringsSep " " (v: "--set ${v} ${proxy}") [
          "http_proxy"
          "https_proxy"
          "HTTP_PROXY"
          "HTTPS_PROXY"
          "ALL_PROXY"
          "all_proxy"
        ]} \
        --set no_proxy ${noProxy} \
        --set NO_PROXY ${noProxy} \
        --set NODE_USE_ENV_PROXY 1 \
        --set OPENCODE_DISABLE_LSP_DOWNLOAD true \
        --prefix PATH : ${lib.makeBinPath [ pkgs.mcp-searxng ]}
    '';
  };

  # keys from nixos/services/opencode-keys.nix. opencode reads the files
  # itself, they are not in its env, so the agent's commands don't get them
  keys = lib.filterAttrs (n: _: lib.hasPrefix "opencode/" n) (osConfig.sops.secrets or { });
  providers = lib.mapAttrs' (
    n: s: lib.nameValuePair (lib.removePrefix "opencode/" n) { options.apiKey = "{file:${s.path}}"; }
  ) keys;

  # jq, not toJSON: nix sorts the keys, the permission rules are last-match-wins
  settings = pkgs.runCommand "opencode.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq --argjson p ${lib.escapeShellArg (builtins.toJSON providers)} '.provider = $p' \
      ${repo}/opencode.json > $out
  '';
in
{
  home.packages = [ opencode ];

  # store files: opencode keeps its state in ~/.local/state/opencode, the
  # config stays read-only, so the agent can't rewrite its own policy
  xdg.configFile = {
    "opencode/opencode.json".source = settings;
    "opencode/skills/docs".source = "${repo}/skills/docs";
    "opencode/AGENTS.md".source = "${repo}/AGENTS.md";
    "opencode/commands".source = "${repo}/commands";
  };
}
