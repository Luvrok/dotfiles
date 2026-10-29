# pi

Plain config for [pi](https://pi.dev) with local models behind llama-swap. On NixOS, `home/programs/pi` links these files into `~/.pi`. Elsewhere, link them by hand.

| File | Goes to |
|---|---|
| `settings.json`, `models.json`, `mcp.json` | `~/.pi/agent/` |
| `web-search.json` | `~/.pi/` (the legacy path, pi-web-access reads it with or without `XDG_CONFIG_HOME`) |
| `extensions/pi-permission-system/config.json` | `~/.pi/agent/extensions/pi-permission-system/` |
| `skills/*` | `~/.pi/agent/skills/` |

## Debian

```sh
# what the nix wrapper sets, put it in ~/.profile
export PI_TELEMETRY=0
export NPM_CONFIG_PREFIX="$HOME/.local/share/pi/npm/"
export PATH="$NPM_CONFIG_PREFIX/bin:$PATH"

npm install -g --ignore-scripts @earendil-works/pi-coding-agent

d=~/dotfiles/pi
mkdir -p ~/.pi/agent/skills ~/.pi/agent/extensions/pi-permission-system
ln -s $d/settings.json $d/models.json $d/mcp.json ~/.pi/agent/
ln -s $d/web-search.json ~/.pi/
ln -s $d/extensions/pi-permission-system/config.json ~/.pi/agent/extensions/pi-permission-system/
ln -s $d/skills/* ~/.pi/agent/skills/
```

- The `docs` entry in `mcp.json` and `skills/docs` need the docs-mcp container (`nixos/services/docs-mcp`). Remove both on Debian.
- `skills/qwen-generate` needs `qwen-batch` and the models in `/var/lib/models`.
- `web-search.json` sends web requests through xray on `127.0.0.1:10808`. Drop `proxy` and `ssrf` if it isn't running.

## Notes

- pi writes `settings.json` and `mcp.json` itself (`/model`, `/thinking`, `/mcp`, `lastChangelogVersion`), so they are links to this repo, not store files. Expect them to show up in `git diff`.
- `contextWindow` in `models.json` repeats `--ctx-size` from `nixos/services/llama-swap/config.yaml`. Change both.
- `apiKey` is `"none"` because pi requires one, llama-swap ignores it.
- Packages are pinned: extensions run with full user rights, and pi-permission-system ships breaking majors. Bump by hand after reading the changelog.
- Compaction fires when `contextTokens > contextWindow - reserveTokens`. `reserveTokens` equals `maxTokens`, so a full reply always fits. The vision model has a 64k window, so it gets its own smaller values in `compaction.modelOverrides`.
- `httpIdleTimeoutMs` is 15 minutes: llama-server sends no headers until llama-swap has loaded the model (up to `healthCheckTimeout`, 300 s) and the whole prompt is read.
- `preserve_thinking` is `false`: the qwen template drops the thinking of turns before the last user message. Old thinking leaves the context, and llama.cpp re-reads only the last user turn from its checkpoint.
- `samplingParamsByThinkingLevel.off` sets `thinking_budget_tokens` 0, so llama-server closes a `<think>` the model opens anyway. The other levels have no cap.
- Qwen's template knows low, medium and xhigh, so high maps to xhigh. Gemma's template is on/off only. gpt-oss can't stop thinking.
- `mcp.json`: `direct` exposure because a local model calls declared tools more reliably than codemode scripts. `fetch_url` is hidden, pi-web-access's `fetch_content` does that. `timeout` is 120 s because embedding a query waits while embed is busy with a sync.
- `web-search.json`: `provider` is `searxng` only, `auto` would silently fall back to Exa. Loopback SearXNG passes the SSRF guard alone, so no `ssrf.allowRanges` that would let `fetch_content` reach local services. YouTube and video are off without Gemini keys.
- Web traffic goes only through xray: `fetch_content` uses `proxy` with no direct fallback, `ssrf.trustEnvProxy` skips the local DNS lookup so hostnames resolve on the proxy side, and SearXNG has `outgoing.proxies` in `nixos/services/llama-swap/searxng.nix`. With xray down, search and fetch fail instead of going direct.
- `shellCommandPrefix` exports the proxy variables before every bash command of the agent, so curl, wget, git, npm, pip, python and go go through xray, and node `fetch` with `NODE_USE_ENV_PROXY`. Loopback stays direct. It only works for programs that read these variables, and the agent can unset them. ssh, nc, ping and plain DNS ignore them. pi's own requests are not affected.

## Permissions

`extensions/pi-permission-system/config.json` keeps file access inside the working directory plus `~/.pi` and `~/.local/share/pi`. Rules are last-match-wins, keep the key order.

- Extra read-only paths go in `external_directory_read`: `/nix/store`, and `/tmp/pi-*` where pi saves the full output of truncated tool results.
- The agent can't write its own policy, `settings.json` or `mcp.json` (`path_write`), since a new package or stdio server runs with full rights. Nor `.git` (hooks, `core.fsmonitor` run on the next `git status`) or a project's `.pi`.
- File tools (`read`, `write`, `edit`, `grep`, `find`, `ls`) are enforced, symlinks included.
- Bash is enforced only for paths written in the command line. A program reads and writes wherever it wants: `python x.py`, `make`, `go test`, `nix eval --expr`. Every command not on the allow list asks.
- The allow list is read-only commands, minus the flags that run code or write files (`find -exec`, `fd -x`, `rg --pre`, `sort -o`, `git --output`, `--ext-diff`), which ask. So do redirects and `.env` in a command. `sed` (its `e` and `w`), `go` (`go test`, `-toolexec`, `-vettool`) and `nix eval` (reads any file) ask as a whole.
- Network, extensions and MCP servers are not limited by it.
