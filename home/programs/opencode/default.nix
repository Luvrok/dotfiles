{ pkgs, ... }:
let
  repo = ../../../opencode;
in
{
  home.packages = [ pkgs.opencode ];

  # store files: opencode keeps its state in ~/.local/state/opencode, the
  # config stays read-only, so the agent can't rewrite its own policy
  xdg.configFile = {
    "opencode/opencode.json".source = "${repo}/opencode.json";
    "opencode/skills/docs".source = "${repo}/skills/docs";
  };
}
