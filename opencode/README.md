# opencode

Config for [opencode](https://opencode.ai) with the free models of OpenCode Zen, no local models. On NixOS, `home/programs/opencode` puts these files into `~/.config/opencode`. Elsewhere, link them by hand.

| File | Goes to |
|---|---|
| `opencode.json` | `~/.config/opencode/` |
| `skills/*` | `~/.config/opencode/skills/` |

## Debian

```sh
npm install -g opencode-ai

d=~/dotfiles/opencode
mkdir -p ~/.config/opencode/skills
ln -s $d/opencode.json ~/.config/opencode/
ln -s $d/skills/* ~/.config/opencode/skills/
```

- The `docs` entry in `opencode.json` and `skills/docs` need the docs-mcp container (`nixos/services/docs-mcp`). Remove both on Debian.

## Notes

- The model is `opencode/deepseek-v4-flash-free`. Free models need no account, but only through the opencode client. Zen changes the free list: if the model is gone, pick another `-free` one with `/models` and change `model` and `small_model`. The list: `https://opencode.ai/zen/v1/models`.
- `small_model` is set to the same model, else opencode picks its own small model for titles, and that one may be paid.
- `enabled_providers` is only `opencode` (Zen), so env keys like `OPENAI_API_KEY` don't add other providers.
- Free models may log prompts for training. Don't send private code or notes. That is why the qmd skill from `home/programs/pi/qmd.nix` is not linked here.
- The config is a store file, not an out-of-store link: opencode doesn't write it, the model you pick with `/models` goes to `~/.local/state/opencode`. Edit the repo file and rebuild.
- `autoupdate` is off, the package comes from nixpkgs. `share` is off, so `/share` can't publish a session.
- MCP tools are named `<server>_<tool>`. `docs_fetch_url` is denied, as in pi. `timeout` is in ms here.
- No web search: opencode's `websearch` needs Exa (`OPENCODE_ENABLE_EXA`). `webfetch` asks, because it goes direct, not through xray, and can reach local services.
- No proxy prefix for bash, opencode has no `shellCommandPrefix`. The agent's commands go direct.

## Permissions

`opencode.json` mirrors `pi/extensions/pi-permission-system/config.json`. Rules are last-match-wins, keep the key order.

- `read` and `edit` deny the same secret paths. `.env` reads are already denied by default, the rules repeat it.
- `external_directory` denies everything outside the working directory except `~/.config/opencode`, `~/.local/share/opencode` (full output of truncated tool results) and `/nix/store`. `edit` then denies writes to `~/.config/opencode` and `/nix/store`.
- Bash is the same allow list as pi, without qmd. Every other command asks. As in pi, a program reads and writes wherever it wants.
- Network and MCP servers are not limited by it.
