{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  repo = ../../../opencode;

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
  home.packages = [ pkgs.opencode ];

  # store files: opencode keeps its state in ~/.local/state/opencode, the
  # config stays read-only, so the agent can't rewrite its own policy
  xdg.configFile = {
    "opencode/opencode.json".source = settings;
    "opencode/skills/docs".source = "${repo}/skills/docs";
  };
}
