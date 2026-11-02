# api keys of opencode's providers (home/programs/opencode), barnard only,
# its env.nix imports this. the keys go in secrets/opencode.json (sops
# secrets/opencode.json, then git add), one per provider id, each optional:
#   google      aistudio.google.com/apikey
#   groq        console.groq.com/keys
#   nvidia      build.nvidia.com
#   openrouter  openrouter.ai/keys
#   cerebras    cloud.cerebras.ai
#   mistral     console.mistral.ai
#   zai         z.ai/manage-apikey
# github-copilot has no key, it logs in with /connect in opencode
{
  lib,
  username,
  ...
}:

let
  secretsFile = ../../secrets/opencode.json;
  hasSecrets = builtins.pathExists secretsFile;
  # sops keeps the names in clear, so only the keys that are there get a secret
  ids = lib.optionals hasSecrets (
    builtins.filter (n: n != "sops") (builtins.attrNames (lib.importJSON secretsFile))
  );
in
{
  warnings = lib.optional (
    !hasSecrets
  ) "secrets/opencode.json is missing (or not git added): opencode has only the free models of Zen";

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
