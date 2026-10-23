# AGENTS.md

NixOS + home-manager dotfiles. This file covers the X11 desktop: i3, picom
(pijulius fork) with animations, and the eww bar, plus its Wayland twins on
sway and Hyprland (with a Quickshell bar and menus). Also the embeddings and docs index on jedha, and the llama.cpp pin
it shares with barnard. Keep it in sync when you change how these parts
talk to each other.

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
| `hosts/jedha/docs-mcp/default.nix` | docs-mcp-server container, read-only MCP on `127.0.0.1:6280/mcp`, `docs-mcp` cli, sync and refresh timers |
| `hosts/jedha/docs-mcp/sources.nix` | the docs to index: name, url, extra `scrape` flags |
| `hosts/jedha/docs-mcp/sync.sh` | `docs-mcp-sync`: scrapes new and changed sources, removes dropped ones |

- llama-server runs from the nixpkgs `services.llama-cpp` module
  (`DynamicUser`, hardened). The model is not in the store, it's downloaded
  by hand to `/var/lib/models/embeddinggemma-2-Q8_0.gguf`.
- docs-mcp-server is the upstream image under podman (`--network=host`,
  pinned tag, no `latest`: a release can migrate the db). It runs the `mcp`
  command with `--read-only`: no web ui, no `/api`, search tools only, no
  jobs. Everything that writes the index goes through the cli. Data in
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
  added by hand (`docs-mcp scrape`) are never touched, and one that was removed by hand comes
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
  `systemctl stop podman-docs-mcp`, `docs-mcp mcp` (starts the server in
  the terminal), answer `y`, Ctrl+C, start the service again. Vectors are
  gone then: set `/var/lib/docs-mcp-sync/state.json` to `{}` and start
  `docs-mcp-sync` to rescrape everything.
- The image sets `HOST=0.0.0.0` and `PORT`, and alias env vars beat the config
  file, so host and port go in as full names (`DOCS_MCP_SERVER_HOST`,
  `DOCS_MCP_SERVER_PORTS_MCP`).
- docs-mcp answers 403 to a `Host` header it doesn't know (only IPs,
  `localhost`, single-label names). Behind a proxy with a domain, set
  `publicUrl` in `docs-mcp/default.nix`.
- Scrape mode `auto` (the default) and `playwright` start Chromium, heavy on
  4 GB. `sources.nix` uses `fetch` unless an entry sets `scrape-mode`, a
  hand-made `docs-mcp scrape` needs `--scrape-mode fetch`. Limits: llama-server
  `MemoryMax=1G`, the server container `--memory=768m` (it scrapes nothing),
  a cli container `--memory=1g`.
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

## Sway (wayland)

The same desktop on sway next to i3, barnard only (`hosts/barnard/env.nix` imports it). SDDM lists both
sessions (its greeter stays on X11 and starts Wayland sessions fine), i3
stays the default. All of it lives in `nixos/services/sway/`, no
home-manager. Same tags, binds, scratchpads and bar, no animations.

| Path | What |
| --- | --- |
| `nixos/services/sway/default.nix` | `programs.sway`, the no-tab-bar patch, session env, gtk dconf, `/etc/sway/*`, scripts |
| `nixos/services/sway/config` | sway config, the twin of the i3 one |
| `nixos/services/sway/scripts/sway-ws`, `sway-tile`, `sway-sp` | `i3-ws`, `i3-tile`, `i3-sp` minus the picom parts |
| `nixos/services/sway/scripts/sway-clip`, `sway-shot` | `rofi-greenclip` and `flameshot gui` on cliphist, grim, slurp |
| `nixos/services/sway/scripts/eww-sway-*`, `sway-xkb` | bar listeners and launcher |
| `nixos/services/sway/eww/` | bar config (`/etc/sway/eww`), its own eww daemon |

- No animations: swayfx has them (pop in/out, gliding tiles, tag
  crossfade), but its renderer keeps 5 output-sized effect buffers per
  monitor even with blur off, ~150 MB of VRAM on two 1440p monitors. To go
  back: `swayfx`/`swayfx-unwrapped` in `default.nix`, `animation_duration_ms`
  in the config.
- `$mod+Shift+F7` turns the second monitor off and the main one to 240 Hz,
  `$mod+F7` back to both at 120 Hz.
- The X11-only user services (picom, redshift, flameshot, greenclip) are
  wanted by `nixos-fake-graphical-session.target`. Only the X session wrapper
  starts it (i3, dwm), sway's `sway-session.target` pulls in
  `graphical-session.target` only, so they'd start under sway otherwise.
  dunst runs in both (under Hyprland Quickshell is the notification
  server, see there).
- sway gets their stand-ins from its config: swayidle +
  sway-audio-idle-inhibit (xidlehook), gammastep (redshift), cliphist
  (greenclip), `xrdb -merge ~/.Xresources` (the X session wrapper does it
  for i3). The eww wifi and keys menus and rofi-recording (x11grab) are i3
  only.
- Session env is in `extraSessionCommands`: `NIXOS_OZONE_WL` (chromium and
  electron apps run on Wayland), `QT_QPA_PLATFORM=wayland;xcb`,
  `ROFI_PASS_CLIPBOARD_BACKEND=wl-clipboard` (`rofi-pass.nix` reads it).
  Firefox, GTK, Qt6, mpv and kitty pick Wayland on their own. The rest goes
  through Xwayland, the GPU works there too.

### Facts that drove the design

- The sway tree is the i3 one with a few changes: Wayland windows have
  `window: null` but a `pid` and `app_id`, outputs hold workspaces directly
  (`current_workspace`), `floating` is `user_on`/`auto_off` like in i3.
  `swaymsg -t subscribe -m -r` prints one event per line as
  `{ "change": "new", ...`, spaces included.
- No primary output in sway. The main monitor (tags 1..9) is the first
  plugged-in output of the `workspace 1 output` line, `sway-ws` and
  `eww-sway-workspaces` read it with `swaymsg -t get_config`.
- Output names are kernel connectors: X11 `DisplayPort-0` is `DP-1`.
- sway matches `bindsym` by the keysym of the active layout, so on ru
  `$mod+j` is `Cyrillic_o` and nothing fires. Every key bind has
  `--to-code` (key position of the first layout), i3 does that by itself.
- `layout default` in sway goes back to the last split of that container and
  fails on a fresh tabbed one, `$mod+t` uses `layout splith`.
- `container_titlebar_height()` patched to 0 hides tab bars, the same path
  `hide_lone_tab` uses for a lone tab.
- `scratchpad show` ends fullscreen in sway too, so `sway-sp` keeps the
  fullscreen guard. `floating enable` keeps fullscreen, so `sway-tile`
  floats fullscreen windows like `i3-tile`, else the tiles glide back once
  it closes.
- `input xkb_switch_layout next` kills sway (an assert) while a keyboard
  without layouts is plugged in, wtype makes one. `sway-xkb` sets the index.
- Lazy Xwayland quits 10 s after the last X client and loses what `xrdb`
  loaded, so the config has `xwayland force`.
- GTK3 on Wayland with `GTK_USE_PORTAL=1` reads theme, icons, font and cursor
  from the settings portal (dconf) and skips `settings.ini`, so the sway
  module puts the `settings.ini` values in dconf too. X11 GTK doesn't read
  them.
- The sway module turns on `runXdgAutostartIfNone`, which would start XDG
  autostart files in i3. `default.nix` turns it off again.
- The sway module writes `sway-portals.conf`, it replaces `portals.conf`
  under sway, so the termfilechooser line is repeated there.

Test without hardware: `WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2
WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman sway -c <config>`, keys
through `wtype -M logo -k 3 -m logo`, pictures through `grim -o HEADLESS-1`.

## Hyprland (wayland)

The same desktop on Hyprland next to i3 and sway, barnard only
(`hosts/barnard/env.nix` imports it), i3 stays the default. Hyprland's own
layouts and dispatchers do what the sway-* scripts do, Quickshell is the
bar, the wallpaper, the notifications (instead of dunst) and the menus
that stand in for the rofi scripts (`home/local/sh/rofi-*` stay for i3 and
sway). All of it lives in
`nixos/services/hyprland/`, no home-manager. The config files are plain
Hyprland Lua, QML and shell, no nix in them.

| Path | What |
| --- | --- |
| `nixos/services/hyprland/default.nix` | `programs.hyprland`, `/etc/xdg/hypr/hyprland.lua` (checked while it builds), `/etc/xdg/quickshell/hyprland`, packages, session target, dunst off, portal, dconf |
| `nixos/services/hyprland/hyprland.lua` | Hyprland config, the twin of the sway one |
| `nixos/services/hyprland/quickshell/shell.qml` | bar and wallpaper per monitor, the menus, the ipc targets |
| `nixos/services/hyprland/quickshell/{Bar,Wallpaper,Hypr,Theme}.qml` | the bar (tags, the open tag's windows as squares, status), `output * bg`, the bar's Hyprland state and the focused screen, gruvbox colors |
| `nixos/services/hyprland/quickshell/{Notifs,NotifyPopup}.qml` | the notification server (`org.freedesktop.Notifications`), the popup |
| `nixos/services/hyprland/quickshell/{Media,Toggles,Kb}.qml` | singletons: the player and cava's levels, the switches' states, layout-proof keys |
| `nixos/services/hyprland/quickshell/{Shot,Lock}.qml` | the screenshot over a frozen frame, the lock screen |
| `nixos/services/hyprland/quickshell/cava.conf`, `nixos/services/hyprland/proxychains.conf` | the visualizer's cava, the run menu's proxychains (`/etc/proxychains-xray.conf`) |
| `nixos/services/hyprland/quickshell/Menu.qml` | rofi -dmenu: the menu window, filter, list, keys, built from `widgets/` |
| `nixos/services/hyprland/quickshell/widgets/` | the menu parts: `MenuHead` (icon, title, status, pulse), `SearchField` (the text line), `MenuRow`, `KeyHints`, `Meter` and `Threads` (the system menu's bars), `Fader` (a mixer line), `Tile` (a big square of tools and switches), `Visualizer` (cava's bars) |
| `nixos/services/hyprland/quickshell/menus/` | one menu per rofi script: Run, Clip, Librewolf, Power, Bluetooth, Pass, Kill, Audio, Translate, Wifi, Record, Askpass. And System (a small btop), Processes, Calendar, Notifications, Windows, Player, Nix (nixos builds), Dmenu (hypr-dmenu), and Tools with Emoji, Calc, Units (systemd) and Switches |
| `nixos/services/hyprland/TODO.md` | what's left to do here, a plain list |
| `nixos/services/hyprland/quickshell/scripts/` | `record` (wf-recorder + ffmpeg), `bt-pair` (expect, bluetoothctl agent), `wifi` (iwd over d-bus, the menu's networks and the bar's signal), `apps` (the kill menu's apps), `sysmon` (the system menu's numbers), `route` (the audio menu's wires), `units` (systemctl and journalctl for the systemd menu), `nixrun` (the nix menu's commands into its terminal), `proxied` (run's xray mode), `revive` (run's apps that hide in the background), `savefile` (`hypr-savefile`, "save as" through the file chooser portal), `dmenu` (`hypr-dmenu`), `askpass` and `pinentry` (`hypr-askpass`, `hypr-pinentry` in PATH) |

- Both configs sit in `/etc/xdg` and are found through `XDG_CONFIG_DIRS`,
  `~/.config/hypr/hyprland.lua` or `~/.config/quickshell/hyprland` would win.
  On another distro copy them there.
- hyprland.lua starts `qs -c hyprland` and talks to it over Quickshell ipc:
  `qs -c hyprland ipc call menu open <name>` (a second press closes it),
  `bar toggle`, `record stop`, `notifications close` (the popup, $mod+Shift+n),
  `notifications quiet`, `notifications clear`, `shot take` (print), `lock
  now`. `hypr-dmenu` calls `dmenu ask <rows file> <prompt> <row> <markup>`
  and waits for `dmenu answered`. `hypr-askpass` calls `askpass ask <prompt>`,
  `hypr-pinentry` `askpass query <kind> <prompt> <desc> <error>`, both print
  what `qs ipc wait askpass answered` gets. The askpass menu has its own
  loader (`asking`), not `menu`, so it opens over a hidden menu that waits
  for it (pass runs gpg, gpg asks).
- A menu is a layer-shell window with exclusive keyboard focus and a
  `HyprlandFocusGrab`: esc or a click outside closes it, like rofi exiting the
  script. Hyprland still handed the keys to a window now and then (after
  bluetooth on or a scan, not reproduced in a container), so when they
  leave quickshell while a menu is open, it turns on-demand and exclusive
  again 50 ms later: Hyprland focuses a layer that turns exclusive. The
  askpass menu on top keeps quickshell active, so they don't fight. Every page is a `show(rows)` call. While a command runs the menu
  stays and pulses (`wait("scanning")`, the next `show` ends it), only pass
  hides for pinentry.
- The look is the eww wifi menu (`home/programs/eww/wifi-menu`), the
  parts live in `widgets/` so a change there is a change in every menu: a
  head with an icon, title, status (`statusAccent` for an "on") and a pulse
  (`busy` blocks the keys, `activity` doesn't), a dim `note` (what gpg
  says about the key), the text line (a `>`, the text, the count, a
  hairline that turns orange from the left while it has the keys, it folds
  away when closed), the rows, and the keys at the
  bottom (`[[key, what], ...]`, a dot after each). A row is `"name\tinfo"`
  (info dim on the right) or `""` (a divider the cursor skips), `active`
  rows are orange, `empty` fills a list with no rows, `body` puts more
  between the head and the text line (System's meters, the calendar).
  Rows are things to
  pick, actions are keys (`actions` in the hints: wifi `r`/`d`, bluetooth
  `o`/`s`/`p`/`t`/`a`/`v`, translate `alt+p`..., kill `alt+p`, pass
  `ctrl+a` and `t`, backspace or `h` goes back in pass). Every menu sits 10px under the bar and 10px from the right,
  Hyprland slides it in from the right edge, fades it and dims the screen
  around it (layer rule for `menu`: `animation = "slide right"`,
  `dim_around`, `decoration.dim_around` as strong as `dim_special`). Inside,
  new rows come in one after another and the cursor glides.
- Search: `input` gives the text line the keys. Run, clipboard, kill, the
  pass entries, translate's pages and the prompts open with it, q types
  there. A `searchable` menu (wifi, bluetooth) opens on its list, `/` opens
  the search, q in an empty search goes back to the list, tab too but
  keeps the filter, q in the list drops the filter. Esc always closes.
- The bluetooth adapter shows up a moment after Quickshell first asks
  BlueZ, so the menu follows it live (`onAdapterChanged`, the adapter's
  signals, a 1 s relist) instead of reading it once. A scan doesn't block
  the keys, devices come in as they're found.
- Wifi reads iwd over d-bus like the eww wifi menu (`scripts/wifi`):
  `GetOrderedNetworks` gives the signal in dBm * 100, strongest first. The
  device is iwd's first station, the script says which (`dev`), iwctl
  connects and disconnects it (only its exit code counts). The bar's
  signal is `scripts/wifi signal`, the connected network's. The
  list is there at once, a scan fills it in every 0.5 s and doesn't block
  the keys. iwctl prints 4 stars for every network and greys the weak
  ones out with color codes, so counting stars gave full bars everywhere.
- Run lists the apps from their desktop entries (`DesktopEntries`,
  shell.qml reads them at start, it's slow the first time), most used first
  (`~/.local/share/hypr-run`, "count<tab>id"). Typed text with no match runs
  as a command (`;` at the end: in a terminal). Every executable in PATH,
  like rofi-menu's `dmenu_path`, is thousands on NixOS.
- Kill lists apps (`scripts/apps`): every process with a wayland or x11
  connection, found through `ss -xp` (the peers of the sockets' server
  ends), folded into its topmost such process, with its windows from
  `hyprctl clients`. One without a window is "background", like an app that
  lives on after its window closes (no tray here). Enter TERMs the app and
  everything it started, KILL after 2 s. alt+p goes to Processes.
- A menu's `goTo(name)` asks shell.qml for another menu in its place
  (`swap`, a call later, the asking one is unloaded): kill alt+p and
  processes alt+a, system p.
- System ($mod+Escape, a click on the bar's memory) is a small btop, from
  `scripts/sysmon` (a json line a second, /proc, sysfs, hwmon, df, ip,
  integers only so the ru decimal comma can't get in). The cpu model,
  cores and threads under the head. Left: cpu (clock, temperature), a
  bar for every thread, load (processes running or waiting, over 1, 5
  and 15 min), memory, cache, swap, disks (the mount's last part). Right:
  every amdgpu (load, W, temperature, clock, then vram and gtt, a small
  one next to a big one is "igpu"), the network (the default route's
  interface and address), then vnstat for that interface every 30 s
  (`vnstat --json d 2`, `m 1`, `y 1`, a `--` line after each, bytes since
  jsonversion 2): today
  and yesterday, the month and its estimate at this pace, the year and
  all of it. `p` goes to Processes.
- Processes ($mod+Shift+Escape) is every process from `top -b -c` (the
  last second's cpu, kernel threads left out), a search like Kill's. The
  list sorts itself every second, so it has no cursor until ↑↓
  (`startOnFirst: false`), then the cursor stays on its process. Enter
  ends the one under it or the first match of what's typed (TERM, KILL
  after 2 s), alt+s sorts by memory, alt+a goes to Kill. top runs with
  `LC_ALL=C` and an empty HOME, a toprc would change its columns. The
  columns go by the names in top's header, the command is the last one.
- Calendar ($mod+Ctrl+c, a click on the bar's date): the month with iso
  weeks, mondays first, or the year (`y`). h/j/k/l move the cursor, n/p a
  month (a year), t today, the wheel too. It slides 6% like a tag switch.
- Notifications: `Notifs.qml` is the server, `NotifyPopup.qml` shows one at
  a time, the newest, at the bottom in the middle of the focused monitor
  (`Notifs.popupScreen`, picked before `current` changes), 15px from the
  edge like dunst's `bottom-center`, no dim. One layer per monitor, always
  mapped: it slides up from the bottom edge and back in QML, and lets
  clicks through while it's down (an empty `mask`). 5 s (low 3 s, the app's own
  time if it sets one, 0 stays, critical with none stays), a hairline at the bottom runs
  out and stops under the pointer. Left click: the default action (or the
  only one), right: away, middle: dismissed, the other actions are links.
  A newer one takes the place (a quick fade), `+N` says how many wait. The rest stay in
  the menu ($mod+n, a click on the bar's bell) until they're dismissed or
  their app closes them, 50 at most: enter runs the default action, one
  with more actions opens them as a page, x dismisses, c clears, d is
  quiet (no popups but critical, a crossed bell in the bar). A progress
  (the `value` hint: dwm-volume, dwm-brightness), a low one with a stack
  tag ("Volume: Mute") or a transient one only pops up. The same
  `x-dunst-stack-tag` (or the synchronous hints) of the same app takes the
  older one's place, an app that sends again with its id updates it: if
  it's up, the popup stays, its text and bar change and its time starts
  over (`popped(same)`, no fade, no new slide). They survive a quickshell
  reload (`keepOnReload`), not a restart.
- Audio ($mod+Shift+d, a click on the bar's volume) is a small
  pavucontrol: outputs, inputs, the apps that play and the ones that
  record, live from Quickshell's Pipewire. Each line is a `Fader`: the
  name (orange: the default device), what an app plays (`media.name`, a
  tab, a song), a bar with the volume and, inside it, the level of what
  plays (`PwNodePeakMonitor`), the percent or mute. j/k move, h/l ∓5%
  (shift 1%), 0-9 sets 10..90% and 0 100%, m mutes, enter makes a device
  the default or mutes an app. The mouse drags, clicks or scrolls a bar, a
  left click on a device's name makes it the default, middle or right
  mutes. Volumes are cubic like wpctl's and pavucontrol's. `s` on an app
  or an input sends it somewhere else too, like a wire in qpwgraph: a page
  of what records and the outputs, the ones it goes to orange, enter adds
  or takes away the wire (`scripts/route`). Youtube into discord next to
  the mic, the mic into the speakers, an app on two outputs. A line says
  its wires besides the usual: `→ Discord` on the app, `← LibreWolf` on
  the recorder.
- Tools ($mod+a) keeps the small tools behind one key: big squares, the
  key that opens one in its corner (e emoji, c calc, p color with
  hyprpicker, o ocr, s a region shot). One with a menu opens in its place
  (`goTo`, shell.qml's `swap(name, "tools")` sets `menuParent`), the
  others run. In a tool q goes back (backspace in an empty text line),
  `parentMenu` and `atTop` in Menu, esc closes. New tools go into its
  `tools` list, the old menus keep their own keys.
- Emoji: the symbols a layout lacks (— « » → ≈...) and every emoji of
  unicode's `emoji-test.txt` (`unicode-emoji`, `/share/unicode` is in
  `pathsToLink`), found by name, the recent ones first
  (`~/.local/share/hypr-emoji`). Enter copies, alt+t types it with wtype.
- Calc: qalc (libqalculate) as you type, `LC_ALL=C` for the dot, units
  and currencies too. Enter copies the answer and keeps it in the list,
  ↑↓ and enter copy an older one (`startOnFirst: false`, so enter takes
  the typed one).
- Clipboard shows a picture under the cursor above the text line:
  cliphist's `[[ binary data ... png 640x360 ]]` line is decoded once into
  `$XDG_RUNTIME_DIR/hypr-clip/<id>.<type>`.
- Tools also has t translate (it had $mod+Shift+y, now real fullscreen),
  m player, u systemd, v switches, and s is the screenshot.
- Nix ($mod+Shift+u, the i3 and sway key calls a nixos_menu that isn't
  there): sapply, supdate, sclean
  and `sapply-remote` / `sclean-remote` for the hosts in its `hosts`
  (flake name, resolved through `networking.hosts` in nixos/network.nix). Enter types the command into a mini kitty
  scratchpad (`special:spnix`, $mod+Ctrl+u, font 8, under the bar on the
  right), `scripts/nixrun` shows it first and starts it when it's not up.
  It's a plain scratchpad: hide it while it builds, the scripts' own
  notification says how it went, the sudo password goes there too. One
  that still runs isn't typed into (anything in its foreground besides
  the shell, `kitty @ ls`), a notification says so. t shows or hides it.
- Windows ($mod+x): every window of every tag, the one focused before
  first like alt-tab (`focusHistoryID`), the tag in the dim column
  (`Hypr.tagName`, the bar's names live in `Hypr.labels`). Enter focuses
  (`Hypr.dispatchLater`, once the menu is gone), alt+x closes.
- hypr-dmenu is rofi -dmenu over a menu (`-p`, `-selected-row`, `-format
  i`, `-markup-rows`: tags go, a `<span>` starts the dim column), its own
  loader like askpass. The librewolf tab switcher's native host
  (home/programs/librewolf/rofi-tabs-switcher.nix) gets a `rofi` that is
  hypr-dmenu while `hypr-dmenu --check` finds quickshell, rofi otherwise.
  Ctrl+comma in the browser.
- systemd (tools u): services and timers of both scopes from `systemctl
  list-units --output=json` (`scripts/units`), failed first, running
  orange. alt+s/x/r/e start, stop, restart, enable or disable, enter the
  last 80 journal lines (alt+r works there too, h back). System units go
  through `sudo -A` with hypr-askpass, the menu pulses meanwhile.
- Switches (tools v, a click on the bar's icons): `Toggles.list`, one
  square each, orange while on, a pulse while it switches. vpn is
  `xray.service` (`hosts/barnard/xray.nix`: the git-crypted
  `hosts/barnard/xray.json`, up from boot, restarts 10 s after a crash,
  a polkit rule lets the user start and stop it without a password),
  zapret is `zapret-discord-youtube.service`, dnscrypt
  `dnscrypt-proxy.service`. Checks run every 10 s, 2 s while the menu is
  open, the bar shows the icons of what's on.
- Player (tools m, audio's p): `Media.player` is the one
  picked with tab until another one starts, else what plays before what
  doesn't, a browser after the rest (music stays over a youtube tab, the
  tab shows when nothing else plays), then the one that started last
  (`started`, one that shows up playing counts). Cover, track, a seek bar
  for the mouse, time, a 24-bar visualizer, the players. space, n/p, h/l
  seek 10 s, a goes to audio and audio's p comes back. Not in the bar.
  cava and the position polling run only while the menu is open
  (`Media.watched`) and something plays. shell.qml reads `Media.players`
  at start, so `started` counts from then, not from the menu's first open. mpv shows up through `mpvScripts.mpris`
  (home/programs/mpv.nix).
- Shot (print, tools s): grim takes the focused monitor first, then a
  full-screen layer shows that frame, so it's the moment of the key like
  flameshot. Drag to select (f the whole screen), then r rect, a arrow,
  l line, p pen, m marker, t text, b blur, v selects again, c the color
  of what's drawn next, [ ] width, u or ctrl+z undo. enter copies the
  png, s saves it to flameshot's folder (home/services/flameshot.nix) and
  copies the path, shift+s asks where (hypr-savefile, termfilechooser),
  esc drops it. With no room around the selection the tools sit over the
  keys.
- Lock (`lock now`): the session lock, a clock and the password line on
  every monitor (the compositor picks which gets the keys), pam service
  `quickshell`. swayidle runs it on `loginctl lock-session` (the power
  menu's lock) and before sleep. `misc.allow_session_lock_restore` lets a
  restarted quickshell lock again.
- Run's tab turns on xray (an orange "xray" in the head), what runs then
  goes through `scripts/proxied`: chromium and electron apps (the wrapper
  names electron or chrom, or .pak files sit next to the binary) get
  `--proxy-server=socks5://127.0.0.1:10808`, they skip LD_PRELOAD and the
  env vars. The rest `proxychains4 -q -f /etc/proxychains-xray.conf`
  (socks5 on xray's mixed 10808, names resolve over there) and the
  `*_proxy` vars for what LD_PRELOAD can't reach (go, static binaries).
- Run starts apps through `scripts/revive`: element with no tray hides
  on close, a second start says "other instance detected" and quits, the
  old one never shows. When the start quits within 3 s and the oldest
  process from the same store path (or command) is an app (a wayland or
  x11 connection) with no window, it's ended like the kill menu does and
  the app starts again. One with a window is left alone.
- Notifications fold an app with more than one into a line with its own
  page. r answers one with an inline reply (`↩` in front) in the text
  line, the popup's reply link opens that page (`Notifs.reply`). x on an
  app dismisses all of it.
- Volume and brightness keys repeat while held (`repeating`), they and
  the mute keys work on the lock screen too (`locked`). XF86AudioMicMute
  mutes the default input.
- Pass: enter opens an entry's fields, enter copies one, `t` types it.
  ctrl+a (rofi-pass's autotype key) types the login, tab and the password
  with wtype into the window under the menu (`autotype:` in the entry
  wins, the login is `user`, `login`, `username` or `email`). The secrets
  go to wtype over stdin, not argv.
- gpg-agent's pinentry (`home/programs/gpg.nix`) is `hypr-pinentry` while
  `qs -c hyprland ipc show` finds quickshell, pinentry-rofi otherwise. It
  speaks assuan itself and asks through the askpass menu (pin, confirm,
  message), so it dims like the other menus.
- Menu keys go through `key(e, "j")`: the Qt key or the xkb keycode of the
  us letter, so j/k/r... work on the ru layout too without switching it
  (translate and clipboard search still take russian). A key fires only
  with the ctrl, alt and super it asks for (`key(e, "p", Qt.AltModifier)`),
  ctrl+r is not r. A menu's `keys` gets the list's keys, and in a prompt
  tab and the keys with ctrl, alt or super. Sizes are whole pixels, a fractional height cut off the
  bottom border.
- Animations follow picom in i3 (`home/picom.nix`): the same speeds and
  curves, a 6% `slidefade` on a tag switch, the scratchpad slides down. No
  blur, shadows or rounding.
- Fullscreen is fake ($mod+y, and what an app asks for: mpv's f, a video,
  a browser): the app is told it's fullscreen, the window floats, gets
  the monitor's size with no border and glides there and back like a
  tile, over the bar (a bottom layer). The windows behind stay. Leaving
  it tiles the window again and swaps it back to its place in master
  (`fakefs` in hyprland.lua remembers it, a reload forgets). Classes in
  `real_fullscreen` (steam games, gamescope) and the `game` content type
  get real fullscreen, $mod+Shift+y gives it to anything (direct scanout,
  it grows while the windows behind fade out), on a fake one it comes
  back to fake. mpv in fake fullscreen has the same picture, only direct
  scanout is gone. Idle: `idle_inhibit` "focus" on a fake one, mpv and
  browsers inhibit on their own too.
- Picture-in-Picture isn't pinned, so it can go fullscreen and stays on
  its tag. alt+p in LibreWolf opens it (`key_togglePictureInPicture` in
  `home/programs/librewolf/customKeys.json`, about:keyboard's file),
  $mod+Shift+p sends it to the other monitor in fake fullscreen, again
  brings it back as it was. The focus stays.
- hyprland.lua starts `hyprland-session.target` (bound to
  `graphical-session.target`, like `sway-session.target`). The X11-only user
  services stay off, they hang on `nixos-fake-graphical-session.target`.
  swayidle, sway-audio-idle-inhibit, gammastep, cliphist and `xrdb -merge`
  start from hyprland.lua like in sway.

### Facts that drove the design

- Hyprland 0.56 reads `hyprland.lua` (the hyprlang `.conf` is legacy, the
  wiki only documents Lua). Dispatchers are `hl.dsp.*` values, a bind takes
  one or a function that calls `hl.dispatch`. `hyprctl dispatch` evaluates
  Lua too, Quickshell 0.3 knows it (`Hyprland.dispatch("hl.dsp.focus(...)")`).
  0.56 has no `hl.dsp.reload_config` yet, the wiki is ahead, `hyprctl reload`.
- Check a config without a session: `Hyprland --verify-config -c
  hyprland.lua` (as root add `--i-am-really-stupid`, and XDG_RUNTIME_DIR
  must be set). It parses the file and runs it, bind functions only run on
  the key, exit 1 on an error. `default.nix` runs it in the build, so a
  Hyprland update that changes the Lua api fails `nixos-rebuild` with the
  line, not the login.
- Hyprland's own notifications (Lua runtime errors, monitor modes,
  `hyprctl notify`) are drawn top right, hardcoded in
  `NotificationOverlay.cpp`, no option moves them, a patch would build
  Hyprland from source. Config errors are a bar, `debug.error_position`
  puts it at the bottom.
- Per-monitor tags are `r~N`: the Nth workspace id the focused monitor may
  hold, skipping ids pinned to other monitors or open there. With 1..10
  pinned to DP-2 the second monitor's `r~1` is 11. A pin to a monitor that's
  gone doesn't count, so the one left gets 1..9. The bar finds the main
  monitor through `hyprctl -j workspacerules` (the monitor of workspace 1)
  and numbers the others by x, like sway-ws.
- Focusing a monitor focuses its tag's last focused window. A silent move
  to the other monitor ($mod+Ctrl+comma/period) focuses the window on its
  new tag, then focus and the cursor go back, so it's the one focused
  there later, like dwm's tagmon. The last window of a tag goes like
  $mod+Shift (move with focus, then back): after a silent move the focus
  didn't stick there, the old window came back. Not onto a scratchpad or a
  fullscreen window, focusing would close or unfullscreen them. The `l`/`r` monitor
  selectors stop at the screen edge, the binds use `+1`/`-1`, they wrap.
- master is dwm tile: `layoutmsg cyclenext/swapnext` wrap like i3-tile,
  `addmaster/removemaster` are dwm's incnmaster/decnmaster ($mod+i/d).
  $mod + the mouse's side buttons do $mod+j/k. $mod + wheel goes through
  the tags with windows on the monitor (`m+1`/`m-1`, wraps,
  `binds.scroll_event_delay` 150, the 300 ms default is slow for that).
  monocle is sway's tabbed tag without tab bars, it hides the windows
  behind the focused one with alpha 0 through the `fadeSwitch` animation,
  which is off, so a switch is instant. A workspace rule sets the
  layout per workspace, $mod+t/$mod+m add one at runtime
  (`hl.workspace_rule` merges into the rule of the same workspace and
  re-layouts) and send `hl.dsp.event("layout")`, the bar refetches on
  `custom>>layout`. A reload drops those runtime rules.
- Apps may ask to be maximized (kitty did after a nixpkgs update): a
  maximized window (`fullscreen: 1` in `hyprctl clients`) covers the tag
  like monocle with gaps, hides the master and blows a scratchpad up to
  the screen. A rule for every class has `suppress_event = "maximize"`,
  like Hyprland's example config. A later rule's `suppress_event` replaces
  it, so telegram's viewer lists `fullscreen maximize`.
- A window rule pattern has to match the whole class or title (RE2
  FullMatch), sway matches a part: `qBittorrent$` misses
  `org.qbittorrent.qBittorrent`, hence `.*qBittorrent$`.
- smart_no_gaps: monocle tags get `border_size = 0`, a window rule gives
  floating windows their 1px back (window rules beat workspace rules).
- Hyprland windows can only slide in from a screen edge, pop or gnome, not
  drift a few percent like picom, so they pop from 94%. Workspaces
  (`slidefade 6%`) and special workspaces (`slidefadevert top 6%`) can.
  Hyprland picks the switch direction by workspace id, like i3-ws-anim's tags.
  The bar and the wallpaper have `no_anim`.
- Real fullscreen fades every other window of the tag and the bar to 0
  (`setFullscreenFadeAnimation`, the `fadeIn` speed, no option), the
  wallpaper showed around a window growing to fullscreen. Hence the fake
  one. A rule for every class has `sync_fullscreen = false`: an app's
  request then changes only its client state, no event fires for that
  but `window.update_rules` does (rules can match
  `fullscreen_state_client`), hyprland.lua floats or tiles the window a
  timer tick later, not in the middle of the rule pass. `fullscreen_state`
  with internal 0 and client 2 is what the app sees. The dispatcher leaves
  sync on when both states match, `set_prop sync_fullscreen unset` after
  each one gives the rule back.
- Each layout keeps its own fullscreen states. Telling a tile it's
  fullscreen and then floating it left the state with master, and $mod+y
  froze Hyprland. The window floats first, then gets client 2 (like
  telegram's viewer), an app's request on a tile is taken back first.
- monocle's only layoutmsgs are cyclenext and cycleprev, an `mfact` is a
  Lua runtime error (top right), so $mod+h/l do nothing there.
- A window resize in master (keys or mouse) never animates, the layout
  forces warps in `resizeTarget`. `layoutmsg mfact` does animate, so
  $mod+h/l use it on tiled windows. Stack heights have no layoutmsg, so
  $mod+Shift+h/l only resize floating windows. dwindle animates keyboard
  resizes (`misc.animate_manual_resizes`), but it splits any window, it
  was tried and dropped.
- Hyprland puts `gaps_in` on every side of a window and doesn't add it at the
  screen edge: sway's inner 10 / outer 0 is `gaps_in = 5`, `gaps_out = 10`.
- Scratchpads are special workspaces. `on_created_empty` starts the app when
  the toggle finds none, `close_special_on_empty` drops it when the app
  quits. hide/showall park windows in `special:hide_<tag>` and move them
  back, tiled or floating as they were.
- `hl.dsp.focus` warps the cursor to the middle of the window it focuses
  (or of the monitor a tag lives on), `cursor.no_warps` would stop the
  monitor binds from warping too. The bar's clicks send one Lua function
  (`hyprctl dispatch` is `return hl.dispatch(...)`, a function works) that
  focuses and puts the cursor back, like i3's `mouse_warping output`.
- SplitParser glues a blank line to the next one ("\ntop - ..."), match
  lines with a leading `\s*`.
- The bar has no window titles and no layout symbol. The windows of the
  open tag are 4px squares after the tags (master, the stack, floating
  last), 3 rows with 3px above, between and under them on the 24px bar,
  then the next column, up to 30. The filled one is the tag's last focused
  window, a click focuses one (the gap around a square counts), the wheel
  goes to the next or the previous one. The bar font is in px (14, the eww
  bar's 10pt plus a bit), the menus' in pt.
- Quickshell keeps `lastIpcObject` (layout, last window, window positions,
  floating) from its last fetch, Hypr.qml refetches workspaces and clients
  50 ms after window, workspace and custom events.
- wf-recorder needs `-D`: it asks for frames on damage only, on a still
  screen it never writes and never stops. It takes one audio source, so
  sound goes through ffmpeg (fifo, `-c:v copy`, `-shortest` ends it with
  the video). It records one monitor, fullscreen is the focused one.
- Quickshell.Bluetooth (BlueZ over D-Bus) gives the state, the toggles,
  connect and disconnect (done when the device's state leaves connecting
  or disconnecting, `connected` says how it went). Pairing goes through
  `scripts/bt-pair` (expect, bluetoothctl as the agent) like
  rofi-bluetooth, Quickshell has no agent. A PIN the device asks for comes
  from the menu over stdin.
- Quickshell's NotificationServer takes `org.freedesktop.Notifications`
  only while it's free and takes it as soon as the owner lets go. dunst
  has no unit that starts it, d-bus activation does on the first
  notification, so a drop-in from `default.nix` gives it an
  `ExecCondition`: no start while the pid in
  `$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.lock` lives
  (Hyprland exports the signature to systemd, a stale one points at a dead
  pid or no lock). hyprland.lua stops a dunst left from another session.
- Quickshell's Pipewire types by `media.class`: an app that plays is
  `AudioOutStream` (it has the Sink flag, `isSink` is true), one that
  records `AudioInStream`, so Audio goes by `type`. A level meter is a
  capture stream named after the program (`.quickshell-wrapped`,
  `stream.monitor` true): one on a recording stream would meter the
  meters, so they're only on outputs, inputs and apps, and streams show
  once they're bound (`ready`) and aren't monitors. The meters live in a
  `Variants` on the nodes, not in the lines: the Repeater makes its lines
  again when the list changes, a new meter changes the node list, and the
  list only changes when its `shape` string does.
- `scripts/route` reads ports and links from `pw-dump` (json) and wires
  them with `pw-link`: the same `audio.channel`, all to a mono input, else
  by order. pw-link's links linger after it quits, wireplumber leaves
  links it didn't make alone, they go with either node. Quickshell can
  read links (`Pipewire.linkGroups`, source and target nodes) but not make
  them.
- A menu's own property or function must not take a name Menu has
  (`shown`, `move`, `title`...), it shadows Menu's and breaks it. An id
  that's also a property of the same object wins over the property:
  `id: volume` on the bar's volume label printed the label.
- Quickshell's `Notification.expireTimeout` is the app's ms passed
  through, its doc says seconds, so the popup counts a small one as
  seconds. The bar's memory is MemTotal - MemAvailable from /proc/meminfo,
  like free's "used".
- Hyprland and its portal come from nixpkgs without the overlays
  (`import pkgs.path`): the dmenu fork in `nixos/overlays` changes uwsm,
  hyprland's uwsm session file points to it, and that hyprland misses the
  binary cache and builds from source.
- Hyprland ships `hyprland-portals.conf`, it replaces portals.conf under
  Hyprland, so `default.nix` writes it with the termfilechooser line.
- The Hyprland module turns on `runXdgAutostartIfNone` like the sway one,
  `default.nix` turns it off again.
- Quickshell's JS `Array.sort` isn't stable: sorting the connected network
  on top shuffled iwd's order. Menus use a filter or a total order.
- A component's own property must not take a name its type has: Shot's
  drawing color is `ink` (a window has `color`), Tile's state is `mode`
  (an Item has `state`), a Process can't have an `id` property.
- mpris doesn't push the position while it plays, Media calls
  `positionChanged()` every second. cava's raw output (ascii, `;` between
  bars, a line a frame) comes through a SplitParser.
- Shot draws on a Canvas over the frame, the blur is a mosaic: each 12 px
  cell is the frame's pixel in its middle (`drawImage` 1x1 to the cell),
  no shaders, so it works on any renderer. The selection is an Item that
  clips a second copy of the frame and the canvas, `grabToImage` on it is
  the png.
- A value type read from a property (a `color`) is a reference in Qt 6:
  `{ color: ink }` followed the property and recolored every shape, Shot
  keeps the string (`${ink}`).
- Hyprland refuses window focus while a layer has the keys exclusively,
  then focuses the window under the cursor when it unmaps. A tag switch
  still happened, so focus "worked" across tags only. Menus dispatch focus
  100 ms after they hide (`Hypr.dispatchLater`).
- The file chooser portal answers on a request object named after the
  caller's unique name and `handle_token`, `hypr-savefile` (python,
  jeepney) listens there before it asks. termfilechooser puts a help file
  at the suggested path, adds `_` when one is there, and stats what was
  picked, the png replaces it.
- The mini kitty listens on the abstract socket `@hypr-nix`
  (`allow_remote_control=socket-only`, only that kitty), `kitty @
  send-text --stdin` types raw text, a plain `send-text` reads python
  escapes. nixrun waits 150 ms so the menu is gone before the scratchpad
  shows and takes focus.
- A layer that unmaps while a menu holds its focus grab clears the grab
  (`CLayerSurface::onUnmap` refocuses, the grab rejects the window under
  the cursor), so every expired popup closed the open menu. The popup
  never unmaps now, its layer rule is `no_anim`.
- Lock surfaces don't give their items focus, the password line takes it
  (`forceActiveFocus`). Quickshell's pam runs in a helper process, the
  config is `/etc/pam.d/quickshell`.

Test without hardware: Hyprland needs a DRM device and doesn't start in a
container. Notifications need a session bus (`dbus-daemon --session
--fork --print-address`), send them with `busctl --address=... call
org.freedesktop.Notifications /org/freedesktop/Notifications
org.freedesktop.Notifications Notify susssasa{sv}i ...`. Audio needs
`pipewire` and `wireplumber` on the stand's XDG_RUNTIME_DIR, null devices
from `pw-cli create-node adapter '{ factory.name=support.null-audio-sink
... object.linger=true }'`, apps from `pw-play -P '{ application.name=...
media.name=... }'`. Quickshell runs on headless sway (see Sway) with
`QT_QUICK_BACKEND=software`. The systemd menu runs on fake `systemctl`,
`journalctl` and `sudo` in PATH (there's no systemd in a container), the
player on mpv with `mpvScripts.mpris` playing into the test pipewire, the
lock shows but a container's pam can't check a password. The file
chooser runs on `xdg-desktop-portal` and termfilechooser from the store
with a fake `cmd` that writes the path to its 5th argument (and creates
the file), `XDG_DESKTOP_PORTAL_DIR` at termfilechooser's portals. Open a menu with `qs -p <dir> ipc call menu
open <name>`. wtype only reaches it if a virtual keyboard exists before the
menu opens (start a `wtype -s 500000 ...` first). The bar needs Hyprland ipc,
a small fake `.socket.sock`/`.socket2.sock` with `HYPRLAND_INSTANCE_SIGNATURE`
set is enough.
