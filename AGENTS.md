# AGENTS.md

NixOS + home-manager dotfiles. This file covers the X11 desktop: i3, picom
(pijulius fork) with animations, and the eww bar. Also the embeddings and
docs index on jedha, and the llama.cpp pin it shares with barnard. Keep it
in sync when you change how these parts talk to each other.

## Files

| Path | What |
| --- | --- |
| `nixos/services/i3/config` | i3 config: dwm-like tags, scratchpad rules, binds |
| `home/picom.nix` | picom build (fork + 2 patches) and the generated `picom.conf` |
| `home/packages.nix` | builds the scripts below with `writeShellApplication` |
| `home/scripts/i3-ws` | per-monitor tags 1..9 (`i3-ws N`, `move N`, `follow N`, `back`) |
| `home/scripts/i3-ws-anim` | switches or moves with a direction hint for picom |
| `home/scripts/i3-sp` | scratchpads, hide/showall, fade-out before hide/kill |
| `home/scripts/i3-tile` | dwm master/stack daemon, also floats fullscreen windows |
| `home/programs/eww/` | bar: `eww.yuck`, `scripts/eww-i3-*.sh` |
| `home/programs/eww/keys-menu/` | keybind cheat sheet (`keys-menu`, `$mod+/`), pages in `config/keys.conf` |

## How the animations work

picom decides by trigger, the scripts steer it with X properties and opacity.

- Workspace switch: `i3-ws-anim` sets `_WS_SWITCH` (1 = going up, 2 = going
  down) on the client windows of both tags, waits one picom frame (20 ms),
  runs the i3 command, removes the tags after `picom/ws-untag` seconds (under
  a lock, so a newer switch keeps its tags). The `_WS_SWITCH@` rules give a
  horizontal drift. Without tags picom falls back to its ewmh-index
  direction, which is wrong when empty tags come and go.
- Moving a window to a tag (`i3-ws move`, eww right click) also goes through
  `i3-ws-anim`, so the window drifts toward the target.
- Hide or kill through `i3-sp`: a tiled window is floated in place first
  (same frame rect, `border none`, on top, out of the layout), so the tiles
  glide into the gap right away. The content takes the border's pixel, so
  picom sees no size change that could eat the fade. A fullscreen one leaves
  fullscreen the same way, so i3 maps what's under it; those windows get
  `_SP_NOW` and show up at once, the closing one fades on top. Its app is
  frozen (SIGSTOP via `_NET_WM_PID`) until the window is in the scratchpad.
  The border comes back (`border pixel 1`) when a hidden window returns. Then
  opacity goes to 0 (`decrease-opacity` sink while the window is still intact
  and on top), then i3 hides or kills it. Close of i3-managed windows has no
  animation on purpose.
- Several at once: `i3-sp` holds its lock only to float the window, mark it
  `_closing_<id>`, start the fade and focus the last focused window of the
  tag that isn't closing. The lock is free during the fade, so the next
  keypress takes that window. Keypresses on a `_closing_` window do nothing.
  A fullscreen window with no pid to freeze keeps focus (any `focus` would
  end fullscreen), so a second keypress waits for it.
- Scratchpad show: `i3-sp toggle` sets `_SP_SHOW` before `scratchpad show`,
  that rule slides it down like a new window.
- Plain `show`/`hide` (i3 doing it on its own, e.g. everything under a
  fullscreen window) is a quick fade with no movement.
- Fullscreen windows open, show, resize and move with no animation.
- Dock (eww bar) fades on show/hide and workspace triggers, i3 hides it under
  fullscreen. No drift, and no animation on open/close (eww restarts on reload).
- eww popups (wifi menu, keys menu) are override-redirect docks: picom gives
  them nothing on open/close, an eww revealer slides them down instead.
- flameshot: no animations at all.

`slow` in `picom.nix` scales every duration (8 = slow motion + debug log).
Scripts read their timings from `~/.config/picom/fade` and `picom/ws-untag`,
which picom.nix writes, so slow mode stays in sync.

## i3 / picom facts that drove the design

- i3 unmaps every window under a fullscreen one, the bar included. It can't be
  turned off, picom sees plain hide/show.
- `scratchpad show` always ends fullscreen of the focused window, any `focus`
  command does too, and i3 refuses to move a window onto a tag whose
  fullscreen window has focus. So `i3-sp` refuses to bring or launch a
  scratchpad (and `showall`) while the tag has a fullscreen window.
  `popup_during_fullscreen all` plus pointer focus was tried and dropped.
- i3 gives windows in hidden tabs `_NET_WM_STATE_HIDDEN`; browsers, Electron
  and Telegram stop painting then. After a tag switch every window is
  remapped and picom paints nothing until the app draws again, so a hidden
  tab is empty. `i3-sp` strips the flag from the tab that comes up next
  (2nd in its parent's focus order) before the fade.
- `i3-tile` floats a tiled window that opens fullscreen or asks for it within
  1.5 s of opening, and classes in `fs_float` (mpv) whenever they go
  fullscreen. Otherwise the tiles reshuffle and glide once it closes.
- i3 numbers ewmh desktops by position, not by workspace number.
- i3 applies a floating window's own move/resize requests, except while it's
  fullscreen or in the scratchpad (`handle_configure_request`). An app that
  loses fullscreen asks for its windowed size (mpv: small, centered, maybe on
  another monitor), focus follows and `mouse_warping output` moves the
  pointer. That's why `i3-sp` freezes it until it's in the scratchpad.
- After a map a window has no real content until the app paints again. A
  window remapped mid-animation (quick switch back) used to blink for that
  gap: with a border i3 paints the frame at once and the inside is black,
  without one (tabbed tags) picom skips the window as never damaged. Fade-ins
  crossfade from the pre-unmap image (`saved-image-blend`), and the
  `layout.c` patch draws that image while the window has no damage yet. A
  fresh map has no old image and shows up when the app paints.
- i3 `floating enable, border none, resize set W H, move absolute position X Y`
  with the tiled con's `.rect` keeps the frame pixel exact (without
  `border none` it gets the 1 px floating border). It doesn't remap the frame.
- `grp:win_space_toggle` makes level 2 of space `ISO_Next_Group`. i3 resolves
  `bindsym` by the keysym at that level, finds no key, and binds nothing, so
  every `$mod+space` / `$mod+Shift+space` bind is dead.
- picom rules: later rules win; `PROP@` reads the client window, plain `PROP`
  the frame; a missing script means no animation (fading is off). Property
  changes on unmapped windows are applied at the next map, so tagging an
  unmapped window works. This fork never fires `geometry`, use `size` +
  `position`.
- picom starts one trigger per frame, by priority state > position > size >
  opacity, so a geometry change in the same frame eats an opacity animation.
  A new animation interrupting an old one starts each same-named variable
  from the old one's current value, unless it has `reset = true`.
- bash's EPOCHREALTIME uses the locale's decimal point, LC_NUMERIC is
  ru_RU here, so it's a comma. strip it with ${EPOCHREALTIME//[!0-9]/}.

## Debugging

```sh
journalctl --user -u picom -f -o cat | grep --line-buffered -E 'Mapping \(|Unmapping|Starting animation'
```

An unmapped window can only animate again after a real map, so a window that
"appears" without a `Mapping` line is old pixels in another window's buffer.

## jedha: embeddings and docs index

jedha is a small box: i5-7300U (2 cores, AVX2, no AVX-512), 4 GB RAM, zram
swap. Both services listen on 127.0.0.1 only, exposing them (nginx on
mos-eisley, xray) lives elsewhere.

| Path | What |
| --- | --- |
| `flake.nix` | `llama-cpp` input (`flake = false`), the commit is in the url |
| `modules/llm/llama-cpp.nix` | overlay: llama-cpp from that input. jedha and barnard (`nixos/overlays`) import it |
| `hosts/jedha/embeddings.nix` | llama-server, EmbeddingGemma 2, `127.0.0.1:8090` |
| `hosts/jedha/docs-mcp/default.nix` | docs-mcp-server container, `127.0.0.1:6280` (web ui, `/api`, `/mcp`), `docs-mcp` cli, sync and refresh timers |
| `hosts/jedha/docs-mcp/sources.nix` | the docs to index: name, url, extra `scrape` flags |
| `hosts/jedha/docs-mcp/sync.sh` | `docs-mcp-sync`: scrapes new and changed sources, removes dropped ones |

- llama-server runs from the nixpkgs `services.llama-cpp` module
  (`DynamicUser`, hardened). The model is not in the store, it's downloaded
  by hand to `/var/lib/models/embeddinggemma-2-Q8_0.gguf`.
- docs-mcp-server is the upstream image under podman (`--network=host`,
  pinned tag, no `latest`: a release can migrate the db). Data in
  `/var/lib/docs-mcp` (the image runs as uid 1000). The config is a read-only
  JSON from nix. It sends llama-server's `alias` as the model name and gets
  vectors from `http://127.0.0.1:8090/v1`.
- The first start asks the model for its vector size, so the container waits
  for llama-server's `/health`. After that the size is stored in the db.
- `docs-mcp` (root, in PATH) is the cli in a throwaway container on the same
  store, it runs next to the server: `docs-mcp list`,
  `docs-mcp search nix-dev "flake inputs"`, `docs-mcp scrape --help`.
- Sources: `docs-mcp-sync.timer` runs a minute after boot or after a
  `sources.nix` change (`restartTriggers`), then daily. It scrapes what's new
  or changed (`--replace`) and removes what was dropped.
  `/var/lib/docs-mcp-sync/state.json` holds what it scraped, so libraries
  added by hand are never touched, and one that was removed by hand comes
  back. A failed source isn't saved there, so the next run tries again.
  `docs-mcp-refresh.timer` refreshes all sources weekly. Both take the same
  lock.

### Facts that drove the design

- The `gemma-embedding2` arch needs llama.cpp 0.7.0+, nixpkgs has 0.3.0. The
  source comes from the pinned input, the recipe stays from nixpkgs. The
  barnard overlay (rocm, vulkan, `GGML_NATIVE`) stacks on top in any order,
  `.override` keeps an earlier `overrideAttrs`.
- Bump: change the rev in `flake.nix`, `nix flake update llama-cpp`, set
  `npmDepsHash` to `lib.fakeHash`, build, copy the "got:" hash. If the new
  source doesn't build with the old recipe, update `nixpkgs` first.
- `llama-server --version` shows the pinned commit but the recipe's old
  build number (a `let` in the recipe). Cosmetic.
- Never put `GGML_NATIVE=ON` into the jedha build. It's built on barnard
  (Zen 4, AVX-512) and dies with SIGILL on Kaby Lake. The default
  `cpuArchDynamicDispatch` builds every CPU variant and picks one at runtime.
- Quant: Q8_0. F16 gives NaN on CPU (the activations overflow fp16), BF16 has
  no fast path on this CPU. A new quant changes the model name (`alias`).
- A first scrape takes hours on this CPU. The sync services are oneshot with
  `restartIfChanged = false` and only timers start them, otherwise switch
  would wait for the scrape.
- docs-mcp notices a model change by name, and a server without a terminal
  refuses to start then, the cli too. Confirm once by hand:
  `systemctl stop podman-docs-mcp`, `docs-mcp` (no args, starts the server
  in the terminal), answer `y`, Ctrl+C, start the service again. Vectors are
  gone then: set `/var/lib/docs-mcp-sync/state.json` to `{}` and start
  `docs-mcp-sync` to rescrape everything.
- The image sets `HOST=0.0.0.0` and `PORT`, and alias env vars beat the config
  file, so host and port go in as full names (`DOCS_MCP_SERVER_HOST`,
  `DOCS_MCP_SERVER_PORTS_DEFAULT`).
- docs-mcp answers 403 to a `Host` header it doesn't know (only IPs,
  `localhost`, single-label names). Behind a proxy with a domain, set
  `publicUrl` in `docs-mcp/default.nix`.
- Scrape mode `auto` (the default) and `playwright` start Chromium, heavy on
  4 GB. `sources.nix` uses `fetch` unless an entry sets `scrape-mode`, pick
  `fetch` in the web ui too. Limits: llama-server `MemoryMax=1G`, the server
  container `--memory=1536m`, a cli container `--memory=1g`.
- `scope = "subpages"` (the default) keeps the crawl under the start url's
  directory, a last segment without a known extension counts as a directory.
  pkg.go.dev packages sit next to `/std`, hence `scope = "hostname"` plus
  include/exclude regexes (`/.../`, matched on the path) for go-std.
- Some doc sites are blocked from jedha, so every scrape goes through the
  xray http inbound `127.0.0.1:10808` (`proxy` in `docs-mcp/default.nix`).
  docs-mcp has no proxy setting of its own, but all page fetches (GitHub too)
  go through axios 1.18, which reads `HTTPS_PROXY` / `HTTP_PROXY` and
  tunnels https with CONNECT. An http proxy only, axios has no socks.
  `NO_PROXY` keeps llama-server direct. Chromium (`playwright` mode) is not
  covered.
- ubatch is 8192 (the model max, a whole input must fit one ubatch). The
  compute buffer grows with it, look for `compute buffer size` in the log.
  4096 should be enough for docs-mcp chunks (5000 chars max) if memory is
  tight. `threads` 4 vs 2: hyperthreads often add little for matmul.

### Deploy and check

Build on barnard, an overridden llama.cpp has no cache hit and 2 cores with
4 GB build it slowly or OOM:

```sh
nixos-rebuild switch --flake .#jedha --target-host root@jedha --build-host localhost
```

On jedha:

```sh
journalctl -u llama-cpp -b | grep -i load_backend   # haswell variant
curl -s http://127.0.0.1:8090/v1/embeddings -H 'Content-Type: application/json' \
  -d '{"input":"task: search result | query: nix flakes"}' \
  | jq '.data[0].embedding | length, (map(select(. == null)) | length)'
journalctl -u podman-docs-mcp -f
journalctl -u docs-mcp-sync -f                       # scraping progress
docs-mcp list | jq -r '.[] | "\(.name) \(.versions[0].status) \(.versions[0].documentCount)"'
```

The second number must be 0, NaN comes out of the JSON encoder as `null`.

## Conventions

- Code comments: short, casual, lowercase, simple American English, no
  separator lines.
- Scripts run under `writeShellApplication` (errexit, nounset, pipefail,
  shellcheck with SC2016 excluded). Listeners that must not die use
  `set +o errexit`.
- Scripts `unset I3SOCK` when they outlive an i3 restart.
- `keys.conf`: `[name]` starts a page, it opens first when the focused
  window's class is the name (more classes after it). `name:` is a section,
  `keys  what` a row (2+ spaces between). `+` joins a combo, ` / ` puts
  alternatives in one row.
- keys menu closes on Esc, any key that mode "keys" doesn't bind, and any
  click (xinput raw events), so the next bind after mod still runs. Keep the
  mode keys in `i3-keys.conf` and `menu_keys` in the script in sync.
