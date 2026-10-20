# AGENTS.md

NixOS + home-manager dotfiles. This file covers the X11 desktop: i3, picom
(pijulius fork) with animations, and the eww bar. Keep it in sync when you
change how these parts talk to each other.

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

The same desktop on SwayFX (sway with effects, animations among them) next
to i3, barnard only (`hosts/barnard/env.nix` imports it). SDDM lists both
sessions (its greeter stays on X11 and starts Wayland sessions fine), i3
stays the default. All of it lives in `nixos/services/sway/`, no
home-manager. Same tags, binds, scratchpads and bar.

| Path | What |
| --- | --- |
| `nixos/services/sway/default.nix` | `programs.sway` on swayfx, the no-tab-bar patch, session env, gtk dconf, `/etc/sway/*`, scripts |
| `nixos/services/sway/config` | sway config, the twin of the i3 one |
| `nixos/services/sway/scripts/sway-ws`, `sway-tile`, `sway-sp` | `i3-ws`, `i3-tile`, `i3-sp` minus the picom parts |
| `nixos/services/sway/scripts/sway-clip`, `sway-shot` | `rofi-greenclip` and `flameshot gui` on cliphist, grim, slurp |
| `nixos/services/sway/scripts/eww-sway-*`, `sway-xkb` | bar listeners and launcher |
| `nixos/services/sway/eww/` | bar config (`/etc/sway/eww`), its own eww daemon |

- Animations: `animation_duration_ms 250`. New windows pop in (grow from the
  center and fade in), closed ones pop out, tiles glide to their new place,
  tags crossfade. Fullscreen windows and floating drags don't animate, like
  in picom.nix. A window going to the scratchpad goes at once (the tiles
  glide into the gap), one coming back shows up at once. No per-rule
  control and no drift direction like picom has.
- The X11-only user services (picom, redshift, flameshot, greenclip) are
  wanted by `nixos-fake-graphical-session.target`. Only the X session wrapper
  starts it (i3, dwm), sway's `sway-session.target` pulls in
  `graphical-session.target` only, so they'd start under sway otherwise.
  dunst runs in both.
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

- swayfx 0.6 is sway 1.12 plus effects: same commands and IPC, the tree only
  has extra fields. Its renderer needs a DRM device, so it doesn't run
  headless without a GPU, plain sway does (tests below).
- The sway tree is the i3 one with a few changes: Wayland windows have
  `window: null` but a `pid` and `app_id`, outputs hold workspaces directly
  (`current_workspace`), `floating` is `user_on`/`auto_off` like in i3.
  `swaymsg -t subscribe -m -r` prints one event per line as
  `{ "change": "new", ...`, spaces included.
- No primary output in sway. The main monitor (tags 1..9) is the first
  plugged-in output of the `workspace 1 output` line, `sway-ws` and
  `eww-sway-workspaces` read it with `swaymsg -t get_config`.
- Output names are kernel connectors: X11 `DisplayPort-0` is `DP-1`.
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

Test without hardware on plain sway (drop `animation_duration_ms`, it's
swayfx only): `WLR_BACKENDS=headless WLR_HEADLESS_OUTPUTS=2
WLR_LIBINPUT_NO_DEVICES=1 WLR_RENDERER=pixman sway -c <config>`, keys
through `wtype -M logo -k 3 -m logo`, pictures through `grim -o HEADLESS-1`.
