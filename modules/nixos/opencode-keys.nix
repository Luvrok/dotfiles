# api keys of opencode's providers (modules/home/programs/opencode), on a
# host with sops-nix. the keys go in secrets/opencode.json (sops
# secrets/opencode.json, then git add), one per provider id, each optional:
#   google      aistudio.google.com/apikey
#   groq        console.groq.com/keys
#   nvidia      build.nvidia.com
#   openrouter  openrouter.ai/keys
#   cerebras    cloud.cerebras.ai
#   mistral     console.mistral.ai
#   zai         z.ai/manage-apikey
#   context7    context7.com/dashboard, not a provider: the key of the context7 mcp
#               server, modules/home/programs/opencode sends it as a header
# github-copilot has no key, it logs in with /connect in opencode
{
  config,
  lib,
  options,
  username,
  ...
}:

let
  cfg = config.dotfiles.opencode-keys;
  secretsFile = ../../secrets/opencode.json;
  hasSecrets = builtins.pathExists secretsFile;
  # sops keeps the names in clear, so only the keys that are there get a secret
  ids = lib.optionals hasSecrets (
    builtins.filter (n: n != "sops") (builtins.attrNames (lib.importJSON secretsFile))
  );
in
{
  options.dotfiles.opencode-keys.enable = lib.mkEnableOption "opencode's api keys from sops";

  # sops.secrets exists only on a host with sops-nix
  config = lib.mkIf cfg.enable (
    {
      warnings = lib.optional (
        !hasSecrets
      ) "secrets/opencode.json is missing (or not git added): opencode has only the free models of Zen";
    }
    // lib.optionalAttrs (options ? sops) {
      sops.secrets = lib.listToAttrs (
        map (
          id:
          lib.nameValuePair "opencode/${id}" {
            sopsFile = secretsFile;
            format = "json";
            key = id;
            owner = username;
          }
        ) ids
      );
    }
  );
}
