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

    readonly property string liveDir: `${Quickshell.env("HOME")}/HOME/wizzard/wallpaper/live`
    // steam's wallpaper engine: the videos are one level inside each
    // workshop id of app 431960
    readonly property string workshopDir: `${Quickshell.env("HOME")}/.steam/steam/steamapps/workshop/content/431960`
    readonly property string steamDir: `${Quickshell.env("HOME")}/.local/share/Steam/steamapps/workshop/content/431960`
    readonly property string fallback: `${liveDir}/koi-fish-pixel.3840x2160.mp4`
    readonly property string statePath: `${Quickshell.env("HOME")}/.local/state/quickshell/wallpaper`
    readonly property string cacheDir: `${Quickshell.env("HOME")}/.cache/quickshell/wall`

    // the videos (full paths), the one on screen, and per monitor whether
    // the screen behind the windows is visible at all. files is newest
    // first, mtime is each file's mtime in seconds
    property var files: []
    property var mtime: ({})
    property string current: ""
    property var visible: ({})
    property bool loaded: false
    // the lock screen is opaque and the screensaver covers the screen: the
    // wallpaper behind them is paused
    property bool locked: false
    property bool screensaver: false

    readonly property string file: current

    function wrap(i, n) {
        return n === 0 ? 0 : ((i % n) + n) % n;
    }

    function base(path) {
        return path.slice(path.lastIndexOf("/") + 1);
    }

    // added within the last week: the picker marks it "new"
    function isNew(path) {
        const t = mtime[path];
        return t ? (Date.now() / 1000 - t) < 604800 : false;
    }

    // the picker's stills: one ffmpeg at a time, in the order asked. seven
    // at once on 4k videos made the slide stutter
    signal thumbReady(string path)
    property var queue: []
    property var made: ({})
    property string thumbPath: ""
    property string thumbOut: ""

    // a visible card asks for its still first (unshift); the rest of the
    // folder waits behind it, so a scroll never sits in a 40 video queue
    function wantThumb(path) {
        if (path === "" || made[path] === true)
            return;
        const at = queue.indexOf(path);
        if (at !== -1)
            queue = queue.slice(0, at).concat(queue.slice(at + 1));
        queue = [path].concat(queue);
        pump();
    }

    // the whole folder, in the background, one at a time: the picker opens
    // with them ready
    function prefetch() {
        for (const f of files)
            if (made[f] !== true && queue.indexOf(f) === -1)
                queue = queue.concat([f]);
        pump();
    }

    function pump() {
        if (thumbs.running || queue.length === 0)
            return;
        thumbPath = queue[0];
        queue = queue.slice(1);
        thumbOut = thumb(thumbPath);
        thumbs.running = true;
    }

    // the still WallMenu shows for a file, one per path. the cache name is
    // a hash: the same basename in two workshop ids must not share a picture
    function thumb(path) {
        let h = 5381;
        for (let i = 0; i < path.length; i++)
            h = ((h * 33) ^ path.charCodeAt(i)) >>> 0;
        return `${cacheDir}/${h.toString(16)}.jpg`;
    }

    // on screen unless locked or a window covers the monitor: wall-state
    // says the latter, see quickshell/scripts/wall-state
    function play(monitor) {
        return !locked && !screensaver && (visible[monitor] ?? true);
    }

    function pick() {
        // the folder and the saved pick are read at start, whichever comes
        // last chooses; a pick made in this session is not overridden
        if (!listed || !stateRead || current !== "")
            return;
        // the old state kept a bare name from the live folder
        const old = saved !== "" && saved.indexOf("/") === -1 ? `${liveDir}/${saved}` : saved;
        if (old !== "" && files.indexOf(old) !== -1)
            current = old;
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

    // the folder is read again when the picker opens: a video downloaded a
    // minute ago is there without a restart
    function reload() {
        listing.running = false;
        again.restart();
    }

    property string saved: ""
    property bool listed: false
    property bool stateRead: false
    // an event came while wall-state ran: run it once more for the result
    property bool dirty: false

    Timer {
        id: again
        interval: 60
        onTriggered: listing.running = true
    }

    Process {
        id: listing
        running: true
        command: ["wall-list", root.liveDir, root.workshopDir, root.steamDir]
        stdout: StdioCollector {
            onStreamFinished: {
                const files = [];
                const mtime = {};
                for (const line of text.split("\n")) {
                    if (line === "")
                        continue;
                    const t = line.indexOf("\t");
                    if (t < 0)
                        continue;
                    const path = line.slice(t + 1);
                    files.push(path);
                    mtime[path] = Number(line.slice(0, t));
                }
                root.files = files;
                root.mtime = mtime;
                root.listed = true;
                root.loaded = true;
                root.pick();
                root.prefetch();
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

    Process {
        id: thumbs
        running: false
        command: ["wall-thumb", root.thumbPath, root.thumbOut]
        onExited: code => {
            if (code === 0)
                root.made[root.thumbPath] = true;
            root.thumbReady(root.thumbPath);
            root.pump();
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
