import QtQuick
import Quickshell
import Quickshell.Io

// the live wallpaper: mpvpaper on the background layer, one process per
// output. while a window covers the screen it is not killed, it is paused:
// the last frame stays and the decoder does nothing. only another video
// restarts it. the shared file and the policy are in Wall.qml. in photo mode
// there is no process at all; the video stops a moment after the still has
// faded in, so the switch does not flash
Scope {
    id: root

    required property ShellScreen screen

    readonly property string sock: `${Quickshell.env("XDG_RUNTIME_DIR")}/wall-${screen.name}.sock`
    // there is a video to show and the picker is in video mode. modeRead first:
    // a saved photo mode must not flash a frame of the video at login
    readonly property bool there: Wall.loaded && Wall.modeRead && Wall.videoFile !== "" && !Wall.photos
    readonly property bool want: there && Wall.play(screen.name)

    property bool on: false

    function start() {
        if (on || !there)
            return;
        on = true;
        // started playing, the pause follows once mpv's socket is there
        sync();
    }

    function stop() {
        on = false;
        tune.stop();
    }

    // tell mpv to pause or play. the socket appears a moment after
    // mpvpaper starts, so this retries for a few seconds
    function sync() {
        if (!on)
            return;
        tune.tries = 0;
        tune.restart();
    }

    onThereChanged: {
        handoff.stop();
        if (there)
            start();
        else if (Wall.photos)
            handoff.restart(); // let the still cover the last video frame
        else
            stop();
    }
    onWantChanged: if (on) sync()
    Component.onCompleted: if (there) start()

    // another pick: mpvpaper takes its file at start, so it restarts
    Connections {
        target: Wall

        function onVideoFileChanged() {
            if (!root.on)
                return;
            root.stop();
            again.restart();
        }
    }

    Timer {
        id: again
        interval: 300
        onTriggered: root.start()
    }

    // the still (Photo.qml) fades in over the video, then the process goes
    Timer {
        id: handoff
        interval: 260
        onTriggered: root.stop()
    }

    Timer {
        id: tune
        property int tries: 0
        interval: 250
        repeat: true
        onTriggered: {
            if (!root.on) {
                stop();
                return;
            }
            if (ipc.running)
                return;
            ipc.running = true;
        }
    }

    Process {
        id: ipc
        running: false
        command: ["wall-ipc", root.sock, "set pause", root.want ? "no" : "yes"]
        onExited: code => {
            // 24 tries is about 6 s, then the socket is not coming
            if (code === 0 || ++tune.tries >= 24)
                tune.stop();
        }
    }

    Process {
        id: paper
        running: root.on
        command: [
            "sh", "-c",
            'rm -f "$1"; exec mpvpaper -o "no-config loop no-audio no-resume-playback panscan=1 hwdec=auto-safe quiet input-ipc-server=$1" "$2" "$3"',
            "sh", root.sock, root.screen.name, Wall.videoFile
        ]
        // mpvpaper died on its own: back off, then the next event or the
        // poll in Wall.qml tries again
        onExited: code => {
            if (!root.on || code === 0)
                return;
            root.on = false;
            retry.restart();
        }
    }

    Timer {
        id: retry
        interval: 3000
        onTriggered: root.start()
    }
}
