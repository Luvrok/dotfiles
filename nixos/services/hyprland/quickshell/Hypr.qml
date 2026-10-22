pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// what the bar needs from hyprland on top of Quickshell.Hyprland
Singleton {
    id: root

    // the monitor of `workspace 1` in hyprland.lua, it holds tags 1..9
    property string pinned: ""
    // layout of the main keyboard, EN or RU
    property string layout: "EN"

    // monitors, the main one first, then left to right, like sway-ws. the
    // tags of the nth one are workspaces n*10+1 .. n*10+9, the same that r~N
    // gives in hyprland.lua. if the main one is gone, the next one gets 1..9
    readonly property var order: {
        const mons = Hyprland.monitors.values.slice();
        const main = mons.some(m => m.name === pinned) ? pinned : "";
        mons.sort((a, b) => (a.name !== main) - (b.name !== main) || a.x - b.x);
        return mons.map(m => m.name);
    }

    function offset(monitor) {
        return Math.max(0, order.indexOf(monitor)) * 10;
    }

    // the bar's names for tags 1..9 of a monitor
    readonly property var labels: ["scl", "obs", "sh1", "sh2", "smth", "virt", "med", "smth", "vpn"]

    // a workspace as the bar names it: its tag, a scratchpad, or its name
    function tagName(ws) {
        if (!ws)
            return "";
        if (ws.id < 0)
            return ws.name.replace(/^special:/, "");
        const n = ws.id % 10;
        return n >= 1 && n <= 9 ? labels[n - 1] : ws.name;
    }

    // the screen of the monitor that has focus
    function focusedScreen() {
        const focused = Hyprland.focusedMonitor?.name;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === focused)
                return screens[i];
        return screens[0];
    }

    // hyprctl's json, or what to use when it says something else
    function parse(text, fallback) {
        try {
            return JSON.parse(text) ?? fallback;
        } catch (e) {
            console.warn(`hyprctl: ${e}`);
            return fallback;
        }
    }

    // a dispatch once a menu is gone: hyprland won't focus a window while a
    // layer holds the keys, then focuses the one under the cursor
    function dispatchLater(lua) {
        later.lua = lua;
        later.restart();
    }

    function setLayout(name) {
        layout = name.startsWith("Russian") ? "RU" : "EN";
    }

    Process {
        id: rules
        running: true
        command: ["hyprctl", "-j", "workspacerules"]
        stdout: StdioCollector {
            onStreamFinished: {
                const rule = root.parse(text, []).find(r => r.workspaceString === "1" && r.monitor);
                root.pinned = rule ? rule.monitor : "";
            }
        }
    }

    Process {
        running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kb = (root.parse(text, {}).keyboards ?? []).find(k => k.main);
                if (kb)
                    root.setLayout(kb.active_keymap);
            }
        }
    }

    Timer {
        id: later
        property string lua: ""
        interval: 100
        onTriggered: Hyprland.dispatch(lua)
    }

    // quickshell keeps workspace layouts, window positions and last windows
    // from its last fetch, so fetch again after changes. one fetch per burst
    Timer {
        id: refresh
        interval: 50
        onTriggered: {
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            switch (event.name) {
            case "activelayout":
                // keyboard,layout
                root.setLayout(event.data.slice(event.data.indexOf(",") + 1));
                break;
            case "configreloaded":
                rules.running = true;
                refresh.restart();
                break;
            // custom: $mod+t / $mod+m changed a layout
            case "custom":
            case "openwindow":
            case "closewindow":
            case "movewindowv2":
            case "changefloatingmode":
            case "activewindowv2":
            case "workspacev2":
            case "monitoraddedv2":
            case "monitorremoved":
                refresh.restart();
                break;
            }
        }
    }
}
