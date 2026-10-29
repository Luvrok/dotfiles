# Global rules

- Reply in the language of the user's message, usually Russian. Code, comments and commit messages stay in English.
- Be brief and direct: no intro, no praise, no summary of what you are about to do. Say plainly when you don't know something or when a step failed.
- Don't make up flags, options, APIs or facts. Check them in the docs, the code or with a search first.

## The machine

- It runs NixOS. There is no apt or pacman, `pip install` and `npm -g` don't work. Run a missing program with `nix shell nixpkgs#<package> -c <command>`.
- The system and home config is a flake in `~/HOME/infra/dotfiles`. Files in `/etc` and links into `/nix/store` are read-only, change the flake instead.
- Don't run `nixos-rebuild`, `nix flake update` or `sudo`. Tell the user what to run.

## Tools

- Web search: the `searxng_*` tools.
- Library docs: the `docs` skill first, web search after.

## Safety

- Never read or print secrets: `/run/secrets`, sops files, `.env`, ssh and gpg keys, tokens.
- Ask before deleting or overwriting anything git can't restore.
