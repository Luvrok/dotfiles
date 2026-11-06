{
  pkgs,
  lib,
  osConfig,
  ...
}:
let
  # all of opencode through xray (127.0.0.1:10808): gemini answers "user
  # location is not supported" to a direct request. its bash commands get
  # the same env, as pi's shellCommandPrefix. loopback stays direct for docs
  # and searxng. lsp servers and formatters come from modules/nixos/desktop/packages.nix, a
  # downloaded binary doesn't run on nixos
  proxy = "http://127.0.0.1:10808";
  noProxy = "localhost,127.0.0.1,::1";
  proxyFlags = lib.concatMapStringsSep " " (v: "--set ${v} ${proxy}") [
    "http_proxy"
    "https_proxy"
    "HTTP_PROXY"
    "HTTPS_PROXY"
    "ALL_PROXY"
    "all_proxy"
  ];
  wrap =
    binary: package:
    pkgs.symlinkJoin {
      name = "${binary}-wrapped";
      paths = [ package ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/${binary} \
          ${proxyFlags} \
          --set no_proxy ${noProxy} \
          --set NO_PROXY ${noProxy} \
          --set NODE_USE_ENV_PROXY 1 \
          --set OPENCODE_DISABLE_LSP_DOWNLOAD true \
          --prefix PATH : ${lib.makeBinPath [ pkgs.mcp-searxng ]}
      '';
    };
  opencode = wrap "opencode" pkgs.opencode;
  # the desktop bundles its own copy of the cli and runs that, not the one in
  # PATH: the child inherits the env of the app, so the proxy and PATH go on
  # the app. the config, the skills, the sessions and the mcp servers are the
  # same files as the tui's, only cli.json (themes, keybinds) stays terminal
  opencode-desktop = wrap "opencode-desktop" pkgs.opencode-desktop;

  # keys from modules/nixos/opencode-keys.nix. opencode reads the files
  # itself, they are not in its env, so the agent's commands don't get them
  keys = lib.filterAttrs (n: _: lib.hasPrefix "opencode/" n) (osConfig.sops.secrets or { });
  # context7 is an mcp server, not a provider: its key goes in a header below
  providers = lib.mapAttrs' (
    n: s: lib.nameValuePair (lib.removePrefix "opencode/" n) { options.apiKey = "{file:${s.path}}"; }
  ) (lib.filterAttrs (n: _: n != "opencode/context7") keys);
  # context7 without a key works too, on the free limit
  mcpHeaders = lib.optionalAttrs (keys ? "opencode/context7") {
    context7.headers.CONTEXT7_API_KEY = "{file:${keys."opencode/context7".path}}";
  };

  # jq, not toJSON: nix sorts the keys, the permission rules are last-match-wins.
  # the keys go next to the providers opencode.json has (llama-swap), a
  # provider in both gets both
  settings = pkgs.runCommand "opencode.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
    jq --argjson p ${lib.escapeShellArg (builtins.toJSON providers)} \
      --argjson m ${lib.escapeShellArg (builtins.toJSON mcpHeaders)} \
      '.provider = ((.provider // {}) * $p) | .mcp = ((.mcp // {}) * $m) | del(._comment)' \
      ${./opencode.json} > $out
  '';
in
{
  # the app only where there is a session to show it in
  home.packages = [
    opencode
  ]
  ++ lib.optional (osConfig.dotfiles.hyprland.enable or false) opencode-desktop;

  # store files: opencode keeps its state in ~/.local/state/opencode, the
  # config stays read-only, so the agent can't rewrite its own policy
  xdg.configFile = {
    "opencode/opencode.json".source = settings;
    "opencode/skills/notes".source = ./skills/notes;
    "opencode/skills/obsidian".source = ./skills/obsidian;
    "opencode/skills/docs".source = ./skills/docs;
    "opencode/skills/deep-research".source = ./skills/deep-research;
    "opencode/skills/debugging".source = ./skills/debugging;
    "opencode/skills/verify".source = ./skills/verify;
    "opencode/skills/plan".source = ./skills/plan;
    "opencode/AGENTS.md".source = ./AGENTS.md;
    "opencode/commands".source = ./commands;
    # a notification when a permission rule says "ask"
    "opencode/plugins/notify.js".source = ./notify.js;
  };
}
