import QtQuick
import Quickshell
import Quickshell.Io

// the live wallpaper: mpvpaper on the background layer, one process per
// output. Wall.qml says whether it shows; a covered screen gets the process
// killed, not paused, so the decoder's memory goes back. no image under it:
// it sits on the same layer and would cover the video
Scope {
    id: root

    required property ShellScreen screen

    // the process runs, or the compositor's background_color shows
    property bool on: false
    readonly property bool want: Wall.loaded && Wall.file !== "" && Wall.play(screen.name)

    onWantChanged: {
        if (want) {
            grace.stop();
            on = true;
        } else {
            grace.restart();
        }
    }

    Component.onCompleted: if (want) on = true

    // a stop waits a moment: walking the tags must not start and kill mpv
    // for every one of them
    Timer {
        id: grace
        interval: 2000
        onTriggered: if (!root.want) root.on = false
    }

    // mpvpaper takes the file when it starts: the menu's pick restarts it
    Connections {
        target: Wall

        function onCurrentChanged() {
            if (!root.on)
                return;
            root.on = false;
            restart.restart();
        }
    }

    Timer {
        id: restart
        interval: 300
        onTriggered: {
            // the old mpv might still be on its way out
            if (paper.running) {
                restart.restart();
                return;
            }
            root.on = root.want;
        }
    }

    Process {
        id: paper
        running: root.on
        command: [
            "mpvpaper",
            "-o", "no-config loop no-audio no-resume-playback panscan=1 hwdec=auto-safe quiet",
            root.screen.name,
            Wall.file
        ]
        // mpvpaper died on its own: back off, the next event or the poll
        // in Wall.qml tries again
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
        onTriggered: root.on = root.want
    }
}
