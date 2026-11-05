pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// the live wallpapers: the folder they are dropped into, the one on screen,
// and whether it shows on a monitor. WallMenu.qml picks one, Wallpaper.qml
// runs mpvpaper per output. the pick is kept in the state file below, the
// default is the fallback
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("HOME")}/HOME/wizzard/wallpaper/live`
    readonly property string fallback: "koi-fish-pixel.3840x2160.mp4"
    readonly property string statePath: `${Quickshell.env("HOME")}/.local/state/quickshell/wallpaper`
    readonly property string cacheDir: `${Quickshell.env("HOME")}/.cache/quickshell/wall`
    readonly property var extensions: [".mp4", ".webm", ".mkv", ".mov"]

    // the videos in the folder, the one on screen, and per monitor whether
    // the screen behind the windows is visible at all
    property var files: []
    property string current: ""
    property var visible: ({})
    property bool loaded: false
    // the lock screen is opaque, the wallpaper behind it is wasted work
    property bool locked: false

    readonly property string file: current === "" ? "" : `${dir}/${current}`

    function wrap(i, n) {
        return n === 0 ? 0 : ((i % n) + n) % n;
    }

    // the still WallMenu shows for a file
    function thumb(name) {
        return `${cacheDir}/${name}.jpg`;
    }

    // on screen unless locked or a window covers the monitor: wall-state
    // says the latter, see quickshell/scripts/wall-state
    function play(monitor) {
        return !locked && (visible[monitor] ?? true);
    }

    function pick() {
        // the folder and the saved pick are read at start, whichever comes
        // last chooses; a pick made in this session is not overridden
        if (!listed || !stateRead || current !== "")
            return;
        if (saved !== "" && files.indexOf(saved) !== -1)
            current = saved;
        else
            current = files.indexOf(fallback) !== -1 ? fallback : (files.length > 0 ? files[0] : "");
    }

    function set(name) {
        if (name === "" || name === current)
            return;
        current = name;
        Quickshell.execDetached([
            "sh", "-c",
            'mkdir -p "$(dirname "$2")" && printf "%s\\n" "$1" > "$2.tmp" && mv "$2.tmp" "$2"',
            "sh", name, statePath
        ]);
    }

    function check() {
        if (state.running)
            dirty = true;
        else
            state.running = true;
    }

    property string saved: ""
    property bool listed: false
    property bool stateRead: false
    // an event came while wall-state ran: run it once more for the result
    property bool dirty: false

    // the folder is read at start; a new file is picked up by reopening the
    // menu, no rebuild
    Process {
        id: listing
        running: true
        command: ["sh", "-c", 'ls -1 "$1"', "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(f => f !== "" && root.extensions.some(e => f.toLowerCase().endsWith(e))).sort();
                root.listed = true;
                root.loaded = true;
                root.pick();
            }
        }
    }

    Process {
        id: savedFile
        running: true
        command: ["sh", "-c", 'cat "$1" 2>/dev/null', "sh", statePath]
        stdout: StdioCollector {
            onStreamFinished: {
                root.saved = text.trim();
                root.stateRead = true;
                root.pick();
            }
        }
    }

    // per monitor: is the wallpaper visible, from hyprland's workspaces and
    // clients
    Process {
        id: state
        running: true
        command: ["wall-state"]
        onExited: {
            if (root.dirty) {
                root.dirty = false;
                root.check();
            }
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.visible = JSON.parse(text) ?? ({});
                } catch (e) {
                    console.warn(`wall-state: ${e}`);
                }
            }
        }
    }

    // the layout and the windows decide it, hyprland says when they change;
    // a workspace's layout can't change here (the rules pin it), so no
    // event is needed for that
    Connections {
        target: Hyprland

        function onRawEvent(event) {
            switch (event.name) {
            case "workspacev2":
            case "focusedmon":
            case "activewindowv2":
            case "openwindow":
            case "closewindow":
            case "movewindowv2":
            case "changefloatingmode":
            case "fullscreen":
            case "activespecial":
            case "monitoraddedv2":
            case "monitorremoved":
                root.check();
                break;
            }
        }
    }

    // a missed event must not leave the wallpaper dead on a tiled tag
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.check()
    }
}
