pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// the wallpapers: the video folder and the still ones, the pick of each, and
// which kind is on screen. WallMenu.qml picks one, Wallpaper.qml runs
// mpvpaper per output for a video, Photo.qml draws a still on the
// background layer. the picks are kept in the state files below, the default
// video is the fallback. s in the picker switches the two kinds
Singleton {
    id: root

    readonly property string liveDir: `${Quickshell.env("HOME")}/HOME/wizzard/wallpaper/live`
    // steam's wallpaper engine: the videos are one level inside each
    // workshop id of app 431960
    readonly property string workshopDir: `${Quickshell.env("HOME")}/.steam/steam/steamapps/workshop/content/431960`
    readonly property string steamDir: `${Quickshell.env("HOME")}/.local/share/Steam/steamapps/workshop/content/431960`
    // the still wallpapers: the folders next to live, their pictures are
    // found at any depth. live itself is skipped by wall-list
    readonly property string photoDir: `${Quickshell.env("HOME")}/HOME/wizzard/wallpaper`
    readonly property string fallback: `${liveDir}/koi-fish-pixel.3840x2160.mp4`
    readonly property string statePath: `${Quickshell.env("HOME")}/.local/state/quickshell/wallpaper`
    readonly property string photoStatePath: `${Quickshell.env("HOME")}/.local/state/quickshell/wallpaper-photo`
    readonly property string modePath: `${Quickshell.env("HOME")}/.local/state/quickshell/wallpaper-mode`
    readonly property string cacheDir: `${Quickshell.env("HOME")}/.cache/quickshell/wall`

    // the lists (full paths), video or photo by mode, and per monitor
    // whether the screen behind the windows is visible at all. the lists are
    // newest first, mtime is each file's mtime in seconds
    property var videoFiles: []
    property var photoFiles: []
    property var mtime: ({})
    property string videoCurrent: ""
    property string photoCurrent: ""
    property var visible: ({})
    property bool loaded: false
    // "video" or "photo": photo is the quiet one, no mpvpaper and its
    // decoder. s in the picker toggles it, the state file keeps it
    property string mode: "video"

    readonly property bool photos: mode === "photo"
    readonly property var files: photos ? photoFiles : videoFiles
    readonly property string current: photos ? photoCurrent : videoCurrent
    // Wallpaper.qml takes this: it only plays in video mode
    readonly property string videoFile: videoCurrent

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
    // folder waits behind it, so a scroll never sits in a 40 file queue
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

    // the video stays on screen unless a window covers the monitor: wall-state
    // says so, see quickshell/scripts/wall-state. a photo is cheap and stays
    function play(monitor) {
        return !photos && (visible[monitor] ?? true);
    }

    function pickVideo() {
        // the folder and the saved pick are read at start, whichever comes
        // last chooses; a pick made in this session is not overridden
        if (!listed || !stateRead || videoCurrent !== "")
            return;
        // the old state kept a bare name from the live folder
        const old = saved !== "" && saved.indexOf("/") === -1 ? `${liveDir}/${saved}` : saved;
        if (old !== "" && videoFiles.indexOf(old) !== -1)
            videoCurrent = old;
        else {
            videoCurrent = videoFiles.indexOf(fallback) !== -1 ? fallback : (videoFiles.length > 0 ? videoFiles[0] : "");
            if (old !== "")
                console.warn(`wall: saved "${old}" not in ${videoFiles.length} videos, using "${base(videoCurrent)}"`);
        }
    }

    function pickPhoto() {
        if (!photoListed || !photoStateRead || photoCurrent !== "")
            return;
        if (photoSaved !== "" && photoFiles.indexOf(photoSaved) !== -1)
            photoCurrent = photoSaved;
        else {
            photoCurrent = photoFiles.length > 0 ? photoFiles[0] : "";
            if (photoSaved !== "")
                console.warn(`wall: saved "${photoSaved}" not in ${photoFiles.length} photos, using "${base(photoCurrent)}"`);
        }
    }

    function set(name) {
        if (name === "")
            return;
        if (photos) {
            if (name === photoCurrent)
                return;
            photoCurrent = name;
            savePhoto(name);
        } else {
            if (name === videoCurrent)
                return;
            videoCurrent = name;
            save(name);
        }
    }

    // write a pick to its state file, so it survives a restart
    function writeState(path, value) {
        Quickshell.execDetached([
            "sh", "-c",
            'mkdir -p "$(dirname "$2")" && printf "%s\\n" "$1" > "$2.tmp" && mv "$2.tmp" "$2"',
            "sh", value, path
        ]);
    }

    function save(name) {
        writeState(statePath, name);
    }

    function savePhoto(name) {
        writeState(photoStatePath, name);
    }

    function saveMode() {
        writeState(modePath, mode);
    }

    // s in the picker: video to photo and back. a photo needs no mpvpaper, so
    // the video's process, vram and decoder go (the pick stays)
    function toggleMode() {
        if (mode === "video" && photoFiles.length === 0)
            return;
        mode = mode === "video" ? "photo" : "video";
        modeRead = true;
        saveMode();
        if (mode === "photo")
            pickPhoto();
        else
            pickVideo();
        prefetch();
    }

    // the picker's delete: remove the file and its still, drop it from the
    // list. if it is the one on screen, fall back to another file first, so
    // the picker re-indexes to a file that is still there
    function remove(path) {
        if (path === "")
            return;
        Quickshell.execDetached(["rm", "-f", path]);
        Quickshell.execDetached(["rm", "-f", thumb(path)]);
        if (photos) {
            const rest = photoFiles.filter(f => f !== path);
            photoFiles = rest;
            if (photoCurrent === path) {
                photoCurrent = rest.length > 0 ? rest[0] : "";
                if (photoCurrent !== "")
                    savePhoto(photoCurrent);
            }
            if (rest.length === 0) {
                // no stills left: the video comes back rather than a black screen
                mode = "video";
                saveMode();
                pickVideo();
            }
        } else {
            const rest = videoFiles.filter(f => f !== path);
            videoFiles = rest;
            if (videoCurrent === path) {
                videoCurrent = rest.indexOf(fallback) !== -1 ? fallback : (rest.length > 0 ? rest[0] : "");
                if (videoCurrent !== "")
                    save(videoCurrent);
            }
        }
    }

    function check() {
        if (photos)
            return;
        if (state.running)
            dirty = true;
        else
            state.running = true;
    }

    // the folders are read again when the picker opens: a file downloaded a
    // minute ago is there without a restart
    function reload() {
        videoListing.running = false;
        photoListing.running = false;
        again.restart();
    }

    property string saved: ""
    property string photoSaved: ""
    property bool listed: false
    property bool photoListed: false
    property bool stateRead: false
    property bool photoStateRead: false
    property bool modeRead: false
    // an event came while wall-state ran: run it once more for the result
    property bool dirty: false

    onModeChanged: {
        if (mode === "video")
            check();
    }

    Timer {
        id: again
        interval: 60
        onTriggered: {
            videoListing.running = true;
            photoListing.running = true;
        }
    }

    Process {
        id: videoListing
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
                root.videoFiles = files;
                // a new object, so the picker's "new" badges see the change
                const merged = {};
                for (const k in root.mtime)
                    merged[k] = root.mtime[k];
                for (const k in mtime)
                    merged[k] = mtime[k];
                root.mtime = merged;
                root.listed = true;
                root.loaded = true;
                root.pickVideo();
                if (!root.photos)
                    root.prefetch();
            }
        }
    }

    Process {
        id: photoListing
        running: true
        command: ["wall-list", "--photos", root.photoDir]
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
                root.photoFiles = files;
                const merged = {};
                for (const k in root.mtime)
                    merged[k] = root.mtime[k];
                for (const k in mtime)
                    merged[k] = mtime[k];
                root.mtime = merged;
                root.photoListed = true;
                // a saved photo mode with no photos falls back to the video
                if (root.photos && files.length === 0) {
                    root.mode = "video";
                    root.saveMode();
                    root.pickVideo();
                } else {
                    root.pickPhoto();
                }
                if (root.photos)
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
                root.pickVideo();
            }
        }
    }

    Process {
        id: photoSavedFile
        running: true
        command: ["sh", "-c", 'cat "$1" 2>/dev/null', "sh", photoStatePath]
        stdout: StdioCollector {
            onStreamFinished: {
                root.photoSaved = text.trim();
                root.photoStateRead = true;
                root.pickPhoto();
            }
        }
    }

    Process {
        id: modeFile
        running: true
        command: ["sh", "-c", 'cat "$1" 2>/dev/null', "sh", modePath]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.modeRead)
                    return;
                const m = text.trim();
                root.mode = m === "photo" ? "photo" : "video";
                root.modeRead = true;
                root.pickVideo();
                root.pickPhoto();
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
    // clients. only the video needs it, a photo has no process to pause
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
