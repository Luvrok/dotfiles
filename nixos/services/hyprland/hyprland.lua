-- hyprland: the twin of nixos/services/sway/config. same tags, binds,
-- scratchpads and look, done with hyprland's own layouts and dispatchers.
-- animations like picom in i3 (home/picom.nix). the bar, the wallpaper and
-- the menus (the rofi scripts in i3 and sway) are quickshell, its config is
-- `qs -c hyprland`

local mod = "SUPER"

-- quickshell ipc, see quickshell/shell.qml
local function qs(call)
    return hl.dsp.exec_cmd("qs -c hyprland ipc call " .. call)
end

---------------
---- look -----
---------------

hl.config({
    general = {
        border_size = 1,
        -- sway: gaps inner 10, outer 0. hyprland puts gaps_in on each side
        -- of a window and doesn't add it at the screen edge
        gaps_in = 5,
        gaps_out = 10,
        col = {
            active_border = "rgb(d65d0e)",
            inactive_border = "rgb(3c3836)",
        },
        -- dwm tile: master on the left, the stack on the right
        layout = "master",
    },

    decoration = {
        rounding = 0,
        shadow = { enabled = false },
        blur = { enabled = false },
        -- scratchpads and the quickshell menus dim what's under them
        dim_special = 0.25,
        dim_around = 0.25,
    },

    animations = { enabled = true },

    master = {
        mfact = 0.7,
        orientation = "right",
        -- new windows go to the bottom of the stack
        new_status = "slave",
    },

    misc = {
        -- the wallpaper is quickshell, this shows when the file is missing
        background_color = "rgb(171717)",
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        force_default_wallpaper = 0,
        -- a quickshell that dies while locked can lock again when it's back
        allow_session_lock_restore = true,
    },

    -- config errors at the bottom, like the notifications. hyprland's own
    -- notifications (lua errors, monitor modes, hyprctl notify) can't move,
    -- they're drawn at the top right
    debug = {
        error_position = 1,
    },

    binds = {
        -- a shown scratchpad hides when the tag changes, like in sway
        hide_special_on_workspace_change = true,
        -- $mod + wheel goes through the tags, 300 ms a step is slow
        scroll_event_delay = 150,
    },

    input = {
        kb_layout = "us,ru",
        -- win+space switches the layout, so $mod+space binds are dead like in sway
        kb_options = "grp:win_space_toggle",
        follow_mouse = 1,
    },
})

-- animations, the same timings and curves as picom in i3 (speed is in
-- 100 ms). ease out for moves, ease in-out for fade in, linear fade out
hl.curve("out", { type = "bezier", points = { { 0.33, 1 }, { 0.68, 1 } } })
hl.curve("inout", { type = "bezier", points = { { 0.4, 0 }, { 0.2, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

-- tag switch: a 6% drift toward the new tag plus a fade, like i3-ws-anim
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "out", style = "slidefade 6%" })
-- scratchpad: slides down like a new window, sinks when it hides
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 2.5, bezier = "out", style = "slidefadevert top 6%" })
-- windows can't drift a bit in hyprland, a small pop in and out instead
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "out", style = "popin 94%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2.5, bezier = "out", style = "popin 94%" })
-- tiles glide to their new place
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "out" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 2.5, bezier = "inout" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.5, bezier = "linear" })
-- quickshell menus pop like the windows, short fades for app popups
hl.animation({ leaf = "layers", enabled = true, speed = 2.5, bezier = "out", style = "popin 94%" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 2.5, bezier = "inout" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.5, bezier = "linear" })
hl.animation({ leaf = "fadePopupsIn", enabled = true, speed = 0.8, bezier = "inout" })
hl.animation({ leaf = "fadePopupsOut", enabled = true, speed = 0.6, bezier = "linear" })
-- monocle hides the windows behind the focused one with this fade, switch
-- at once like sway's tabs. it also fades active/inactive opacity, unused here
hl.animation({ leaf = "fadeSwitch", enabled = false })
-- border color changes at once, like i3
hl.animation({ leaf = "border", enabled = false })
hl.animation({ leaf = "borderangle", enabled = false })

-- the bar and the wallpaper just appear, fullscreen windows take the screen
-- at once. the quickshell menus sit under the bar on the right, they slide
-- in from the right edge and fade, like a tag switch drifts
hl.layer_rule({ match = { namespace = "^(bar|wallpaper|shot)$" }, no_anim = true })
hl.layer_rule({ match = { namespace = "^menu$" }, animation = "slide right", dim_around = true })
-- the notification popup stays mapped and slides itself (NotifyPopup.qml):
-- a layer that unmaps while a menu holds its focus grab clears the grab,
-- the menu closed whenever a popup ran out
hl.layer_rule({ match = { namespace = "^notification$" }, no_anim = true })
hl.window_rule({ match = { fullscreen = true }, no_anim = true })

-- x11 apps (st, nsxiv, dmenu) read colors and fonts from ~/.Xresources, xrdb
-- below. xwayland starts with hyprland and stays
hl.env("XCURSOR_THEME", "Vanilla-DMZ")
hl.env("XCURSOR_SIZE", "32")
-- chromium and electron apps on wayland (nixos wrappers read it)
hl.env("NIXOS_OZONE_WL", "1")
-- qt5 apps without the wayland plugin fall back to x11
hl.env("QT_QPA_PLATFORM", "wayland;xcb")

------------------
---- monitors ----
------------------

-- DP-2 is the main one on the right, DP-1 on the left
hl.monitor({ output = "DP-2", mode = "2560x1440@120", position = "2560x0", scale = 1 })
hl.monitor({ output = "DP-1", mode = "2560x1440@120", position = "0x0", scale = 1 })
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "auto" })

------------------
---- tags --------
------------------

-- dwm-like tags: every monitor has its own 1..9. the main one is 1..9, the
-- second one 11..19, the bar shows 1..9 on both. $mod+N goes to `r~N`, the
-- Nth workspace that this monitor may hold, so these pins do the mapping.
-- 10 is pinned too, so the second monitor starts at 11. when a monitor is
-- unplugged its pins don't count and the other one gets 1..9
for i = 1, 10 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-2" })
end
for i = 11, 19 do
    hl.workspace_rule({ workspace = tostring(i), monitor = "DP-1" })
end
hl.workspace_rule({ workspace = "1", default = true })
hl.workspace_rule({ workspace = "11", default = true })

-- monocle (sway's tabbed without tab bars, the bar has the titles): tags 1,
-- 2, 9 on both monitors. no gaps and no border, like smart_no_gaps
for _, ws in ipairs({ "1", "2", "9", "11", "12", "19" }) do
    hl.workspace_rule({ workspace = ws, layout = "monocle", gaps_in = 0, gaps_out = 0, border_size = 0 })
end

-- floating windows keep their border on monocle tags
hl.window_rule({ match = { float = true }, border_size = 1 })

-------------------
---- windows ------
-------------------

-- a pattern has to match the whole class or title, not a part like in sway.
-- qbittorrent's app_id is org.qbittorrent.qBittorrent
hl.window_rule({ match = { class = "^obsidian$" }, workspace = "2 silent" })
hl.window_rule({ match = { class = ".*qBittorrent$" }, workspace = "9 silent" })
hl.window_rule({ match = { class = "^v2rayN$" }, workspace = "9 silent" })

hl.window_rule({ match = { title = "^Picture-in-Picture$" }, float = true, pin = true, size = { 720, 400 } })
hl.window_rule({ match = { title = ".*termfilechooser.*" }, float = true, size = { 1000, 700 }, center = true })
hl.window_rule({ match = { class = "^dragon-drop$" }, float = true, center = true })
hl.window_rule({ match = { class = "^ffplay$", title = "^android-webcam$" }, float = true })

-- apps ask to be maximized (kitty after a nixpkgs update): a maximized window
-- covers the tag like monocle with gaps, the master goes under it, and a
-- scratchpad fills the screen. tiles and floats keep their size instead
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

-- telegram's media viewer: the app thinks it's fullscreen, hyprland keeps it
-- a floating window under the bar, so the windows behind stay visible and
-- it pops in like any window
hl.window_rule({
    match = { class = "^org\\.telegram\\.desktop$", title = "^(Media viewer|Просмотр медиа)$" },
    float = true,
    fullscreen_state = "0 2",
    suppress_event = "fullscreen maximize",
    move = "0 0",
    size = "monitor_w monitor_h",
    border_size = 0,
})

-- no screen blanking under a fullscreen window
hl.window_rule({ match = { class = ".*" }, idle_inhibit = "fullscreen" })

-- scratchpads are special workspaces, a toggle on an empty one starts its
-- app. kitty --class sets the app_id
local scratchpads = {
    spterm = "kitty --class spterm --name spterm --title scratchpad",
    spdotfiles = "kitty --class spdotfiles --name spdotfiles --title dotfiles -e sh -c 'cd ~/HOME/infra/dotfiles && nvim'",
    rangerterm = "kitty --class rangerterm --name rangerterm --title ranger -e sh -c 'cd && yazi'",
    -- a mini terminal for the nix menu's builds (quickshell scripts/nixrun
    -- types into it over kitty's remote control)
    spnix = "kitty --class spnix --name spnix --title nix -o font_size=8 -o allow_remote_control=socket-only --listen-on unix:@hypr-nix",
}
for name, cmd in pairs(scratchpads) do
    hl.workspace_rule({ workspace = "special:" .. name, on_created_empty = cmd })
    hl.window_rule({ match = { class = "^" .. name .. "$" }, workspace = "special:" .. name })
end
hl.window_rule({
    match = { class = "^(spterm|spdotfiles|rangerterm)$" },
    float = true,
    size = { 1280, 910 },
    center = true,
})
-- where the menus are: under the bar on the right
hl.window_rule({
    match = { class = "^spnix$" },
    float = true,
    size = { 760, 420 },
    move = { "monitor_w - window_w - 10", "34" },
})

-------------------
---- binds --------
-------------------

-- binds go by the key of the first layout (us), so they work on ru too

-- programs. us for typing, then back to what it was
hl.bind(mod .. " + p", function()
    hl.dispatch(hl.dsp.exec_cmd("hyprctl switchxkblayout all 0"))
    hl.dispatch(qs("menu open run"))
end)
hl.bind(mod .. " + SHIFT + t", hl.dsp.exec_cmd("hyprctl switchxkblayout all 0; kitty"))

hl.bind(mod .. " + c", qs("menu open clip"))
hl.bind(mod .. " + SHIFT + f", qs("menu open librewolf"))
hl.bind(mod .. " + w", qs("menu open power"))
hl.bind(mod .. " + b", qs("menu open bluetooth"))
hl.bind(mod .. " + SHIFT + w", hl.dsp.exec_cmd("webcam"))
hl.bind(mod .. " + r", qs("menu open record"))
hl.bind(mod .. " + SHIFT + r", qs("record stop"))
hl.bind(mod .. " + u", qs("menu open pass"))
hl.bind(mod .. " + CTRL + k", qs("menu open kill"))
hl.bind(mod .. " + SHIFT + u", qs("menu open nix"))
hl.bind(mod .. " + SHIFT + d", qs("menu open audio"))
hl.bind(mod .. " + SHIFT + y", qs("menu open translate"))
hl.bind(mod .. " + CTRL + w", qs("menu open wifi"))
hl.bind(mod .. " + Escape", qs("menu open system"))
hl.bind(mod .. " + SHIFT + Escape", qs("menu open processes"))
hl.bind(mod .. " + CTRL + c", qs("menu open calendar"))
hl.bind(mod .. " + n", qs("menu open notifications"))
-- the small tools: emoji, calc, color, ocr, shot
hl.bind(mod .. " + a", qs("menu open tools"))
-- every window of every tag, like alt-tab
hl.bind(mod .. " + x", qs("menu open windows"))
hl.bind(mod .. " + SHIFT + n", qs("notifications close"))
hl.bind(mod .. " + o", hl.dsp.exec_cmd("kitty --class movies -e yazi /media/outer-1"))

-- print: the screenshot (quickshell Shot.qml, frozen like flameshot). $mod+print:
-- the text of a region to the clipboard, esc in slurp does nothing
hl.bind("Print", qs("shot take"))
hl.bind(mod .. " + Print", hl.dsp.exec_cmd(
    [[g=$(slurp) && grim -g "$g" - | tesseract -l eng+rus stdin stdout 2>/dev/null | wl-copy && notify-send OCR "Text copied"]]))

-- XF86. volume and brightness go on while the key is held (the keyboard's
-- repeat rate), on the lock screen too
local held = { repeating = true, locked = true }
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("dwm-volume mute"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("dwm-volume down"), held)
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("dwm-volume up"), held)
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("dwm-brightness up"), held)
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("dwm-brightness down"), held)

-- monitors: the main one runs at 120 Hz next to the second one and at 240 Hz alone
hl.bind(mod .. " + F7", function()
    hl.monitor({ output = "DP-1", mode = "2560x1440@120", disabled = false })
    hl.monitor({ output = "DP-2", mode = "2560x1440@120" })
end)
hl.bind(mod .. " + SHIFT + F7", function()
    hl.monitor({ output = "DP-1", disabled = true })
    hl.monitor({ output = "DP-2", mode = "2560x1440@240" })
end)

-- scratchpads: show/hide, start the app if it's not there
hl.bind(mod .. " + g", hl.dsp.workspace.toggle_special("spterm"))
hl.bind(mod .. " + v", hl.dsp.workspace.toggle_special("spdotfiles"))
hl.bind(mod .. " + e", hl.dsp.workspace.toggle_special("rangerterm"))
hl.bind(mod .. " + CTRL + u", hl.dsp.workspace.toggle_special("spnix"))

-- setscratch: focused window goes to the $mod+g scratchpad
hl.bind(mod .. " + CTRL + g", function()
    hl.dispatch(hl.dsp.window.float({ action = "enable" }))
    hl.dispatch(hl.dsp.window.resize({ x = 1280, y = 910 }))
    hl.dispatch(hl.dsp.window.center())
    hl.dispatch(hl.dsp.window.move({ workspace = "special:spterm", follow = false }))
end)
-- removescratch: a $mod+g window becomes a tile on this tag, $mod+g opens a new one
hl.bind(mod .. " + SHIFT + g", function()
    local w = hl.get_active_window()
    local ws = hl.get_active_workspace()
    if w and ws and w.workspace and w.workspace.name == "special:spterm" then
        hl.dispatch(hl.dsp.window.move({ workspace = ws.id }))
        hl.dispatch(hl.dsp.window.float({ action = "disable" }))
    end
end)

-- hide / showall: per tag, a hidden window waits in special:hide_<tag> and
-- comes back tiled or floating as it was
hl.bind(mod .. " + CTRL + h", function()
    local ws = hl.get_active_workspace()
    if ws and hl.get_active_window() then
        hl.dispatch(hl.dsp.window.move({ workspace = "special:hide_" .. ws.id, follow = false }))
    end
end)
hl.bind(mod .. " + CTRL + s", function()
    local ws = hl.get_active_workspace()
    local hidden = ws and hl.get_workspace("special:hide_" .. ws.id)
    if not hidden then
        return
    end
    for _, w in ipairs(hl.get_workspace_windows(hidden)) do
        hl.dispatch(hl.dsp.window.move({ window = w, workspace = ws.id, follow = false }))
    end
end)

-- tiling <-> floating focus
hl.bind(mod .. " + semicolon", function()
    local w = hl.get_active_window()
    local floating = w ~= nil and w.floating
    hl.dispatch(hl.dsp.window.cycle_next({ tiled = floating, floating = not floating }))
end)

-- windows
hl.bind(mod .. " + SHIFT + b", qs("bar toggle"))
hl.bind(mod .. " + y", hl.dsp.window.fullscreen())

-- focusstack / pushstack: master, then the stack top to bottom, both wrap
hl.bind(mod .. " + j", hl.dsp.layout("cyclenext"))
hl.bind(mod .. " + k", hl.dsp.layout("cycleprev"))
-- the same on the mouse's side buttons, forward goes like k
hl.bind(mod .. " + mouse:275", hl.dsp.layout("cyclenext"))
hl.bind(mod .. " + mouse:276", hl.dsp.layout("cycleprev"))
hl.bind(mod .. " + SHIFT + j", hl.dsp.layout("swapnext"))
hl.bind(mod .. " + SHIFT + k", hl.dsp.layout("swapprev"))

-- floating windows get resized by 5% of a 2560x1440 monitor. tiles: h/l
-- are dwm's setmfact (layoutmsg mfact animates, a window resize in master
-- jumps), shift+h/l do nothing, no setcfact
local function resize(x, y, mfact)
    return function()
        local w = hl.get_active_window()
        if w and w.floating then
            hl.dispatch(hl.dsp.window.resize({ x = x, y = y, relative = true }))
        elseif w and mfact then
            hl.dispatch(hl.dsp.layout("mfact " .. mfact))
        end
    end
end
hl.bind(mod .. " + l", resize(-128, 0, "+0.05"))
hl.bind(mod .. " + h", resize(128, 0, "-0.05"))
hl.bind(mod .. " + SHIFT + h", resize(0, 72))
hl.bind(mod .. " + SHIFT + l", resize(0, -72))

-- incnmaster / decnmaster
hl.bind(mod .. " + i", hl.dsp.layout("addmaster"))
hl.bind(mod .. " + d", hl.dsp.layout("removemaster"))

hl.bind(mod .. " + SHIFT + c", hl.dsp.window.close())
-- previous tag of this monitor
hl.bind(mod .. " + Tab", hl.dsp.focus({ workspace = "previous_per_monitor" }))
-- $mod + wheel: the next or previous tag with windows on this monitor, wraps
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "m+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "m-1" }))

-- setlayout: tile / monocle for this tag, until a reload. the event tells
-- the bar to redraw its layout symbol
local function set_layout(layout, gaps_in, gaps_out, border)
    return function()
        local ws = hl.get_active_workspace()
        if not ws then
            return
        end
        hl.workspace_rule({
            workspace = tostring(ws.id),
            layout = layout,
            gaps_in = gaps_in,
            gaps_out = gaps_out,
            border_size = border,
        })
        hl.dispatch(hl.dsp.event("layout"))
    end
end
hl.bind(mod .. " + t", set_layout("master", 5, 10, 1))
hl.bind(mod .. " + m", set_layout("monocle", 0, 0, 0))

hl.bind(mod .. " + f", hl.dsp.window.center())
hl.bind(mod .. " + s", hl.dsp.window.pin())

-- focusmon / tagmon: the window goes to the open tag of the next
-- monitor. +1/-1 wrap like dwm, l/r stop at the screen edge
hl.bind(mod .. " + comma", hl.dsp.focus({ monitor = "-1" }))
hl.bind(mod .. " + period", hl.dsp.focus({ monitor = "+1" }))
hl.bind(mod .. " + SHIFT + comma", hl.dsp.window.move({ monitor = "-1" }))
hl.bind(mod .. " + SHIFT + period", hl.dsp.window.move({ monitor = "+1" }))

-- tagmonstay: the window stays the focused one of the tag it lands on, like
-- dwm. focusing it marks it as that tag's last window, then focus and the
-- cursor come back. a plain move onto a scratchpad or a fullscreen window,
-- focusing would close or unfullscreen them
local function tagmonstay(dir)
    return function()
        local w = hl.get_active_window()
        local mon = hl.get_active_monitor()
        local target = hl.get_monitor(dir)
        local cursor = hl.get_cursor_pos()
        if not w or not mon or not target or target.name == mon.name then
            return
        end
        local ws = target.active_workspace
        if target.active_special_workspace or not ws or ws.has_fullscreen then
            hl.dispatch(hl.dsp.window.move({ monitor = target.name, follow = false }))
            return
        end
        if w.workspace and w.workspace.windows == 1 then
            -- the last window of its tag: a silent move and a focus don't
            -- stick then, so move it like $mod+shift does
            hl.dispatch(hl.dsp.window.move({ monitor = target.name }))
        else
            hl.dispatch(hl.dsp.window.move({ monitor = target.name, follow = false }))
            hl.dispatch(hl.dsp.focus({ window = w }))
        end
        hl.dispatch(hl.dsp.focus({ monitor = mon.name }))
        if cursor then
            hl.dispatch(hl.dsp.cursor.move({ x = cursor.x, y = cursor.y }))
        end
    end
end
hl.bind(mod .. " + CTRL + comma", tagmonstay("-1"))
hl.bind(mod .. " + CTRL + period", tagmonstay("+1"))

-- reload / quit
hl.bind(mod .. " + F5", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mod .. " + CTRL + SHIFT + q", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind(mod .. " + SHIFT + BackSpace", hl.dsp.exit())

-- view / tag / tagswitch, on this monitor
for i = 1, 9 do
    hl.bind(mod .. " + " .. i, hl.dsp.focus({ workspace = "r~" .. i }))
    hl.bind(mod .. " + SHIFT + " .. i, hl.dsp.window.move({ workspace = "r~" .. i, follow = false }))
    hl.bind(mod .. " + ALT + " .. i, hl.dsp.window.move({ workspace = "r~" .. i }))
end

-- mouse: move and resize with $mod, tiles too. middle click floats
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind(mod .. " + mouse:274", hl.dsp.window.float())

-------------------
---- autostart ----
-------------------

-- what i3 gets from xserver.nix and the user services: x resources,
-- clipboard history, screen off after 5 min unless audio plays, night colors.
-- hyprland-session.target pulls in graphical-session.target, see default.nix
hl.on("hyprland.start", function()
    hl.exec_cmd("systemctl --user start hyprland-session.target")
    hl.exec_cmd("xrdb -merge ~/.Xresources")
    hl.exec_cmd("wl-paste --watch cliphist -max-items 200 store")
    -- the lock screen is quickshell's (Lock.qml): loginctl lock-session (the
    -- power menu) and suspend lock it
    hl.exec_cmd([[swayidle -w timeout 300 "hyprctl dispatch \"hl.dsp.dpms({ action = 'disable' })\"" resume "hyprctl dispatch \"hl.dsp.dpms({ action = 'enable' })\"" lock "qs -c hyprland ipc call lock now" before-sleep "qs -c hyprland ipc call lock now"]])
    hl.exec_cmd("sway-audio-idle-inhibit")
    hl.exec_cmd("gammastep -m wayland -l 59.9343:30.3351 -t 5000:4000")
    -- quickshell is the notification server, it takes over once a dunst
    -- from another session lets go. default.nix keeps a new one from starting
    hl.exec_cmd("systemctl --user stop dunst.service")
    hl.exec_cmd("qs -c hyprland")
end)

hl.on("hyprland.shutdown", function()
    hl.exec_cmd("systemctl --user stop hyprland-session.target")
end)
