import QtQuick
import Quickshell
import Quickshell.Io
import qs

// jarvis in the bar: a mic while jarvis works or holds the gpu, hidden
// otherwise. orange while it listens or speaks, pulsing while it
// transcribes, thinks, searches or loads the voice, dim while it only
// keeps its models loaded, crossed out while paused. left click: the
// menu, right: stop, middle: free the vram. it watches the daemon's
// socket and comes back when the daemon does
Text {
    id: mic

    // the daemon's state, "" without a daemon
    property string state_: ""
    // jarvis' models llama-swap has up
    property var loaded: []
    property int barHeight: Theme.barHeight

    readonly property string sockPath: `${Quickshell.env("XDG_RUNTIME_DIR")}/jarvis.sock`

    signal openMenu

    readonly property bool working: ["transcribing", "thinking", "searching", "voicing"].includes(state_)
    readonly property bool live: state_ === "listening" || state_ === "speaking"

    function send(msg) {
        if (!sock.connected)
            return;
        sock.write(JSON.stringify(msg) + "\n");
        sock.flush();
    }

    visible: Features.jarvis && state_ !== "" && (state_ !== "idle" || loaded.length > 0)
    text: state_ === "paused" ? "\u{f036d}" : "\u{f036c}"
    color: state_ === "error" ? Theme.urgent : live || working ? Theme.selBg : Theme.dim
    font.family: Theme.barFont
    font.pixelSize: Theme.barFontSize
    verticalAlignment: Text.AlignVCenter
    height: barHeight

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

    SequentialAnimation on opacity {
        running: mic.working
        loops: Animation.Infinite
        onRunningChanged: if (!running)
            mic.opacity = 1
        NumberAnimation {
            to: 0.3
            duration: 500
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            to: 1
            duration: 500
            easing.type: Easing.InOutSine
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor
        onClicked: e => {
            if (e.button === Qt.RightButton)
                mic.send({
                    type: "stop"
                });
            else if (e.button === Qt.MiddleButton)
                mic.send({
                    type: "unload"
                });
            else
                mic.openMenu();
        }
    }

    Socket {
        id: sock
        path: mic.sockPath
        parser: SplitParser {
            onRead: line => {
                let m;
                try {
                    m = JSON.parse(line);
                } catch (e) {
                    return;
                }
                if (m.type === "hello" || m.type === "state")
                    mic.state_ = m.state;
                else if (m.type === "loaded")
                    mic.loaded = m.models ?? [];
            }
        }
        // a passive client: answers still get a notification while it's on
        onConnectedChanged: {
            if (connected)
                mic.send({
                    type: "watch"
                });
            else
                mic.state_ = "";
        }
    }

    // the daemon only runs while it's used: idle for two minutes and it's
    // stopped (the next r in the menu starts it again). its models stay up
    // in llama-swap for their own ttl, the last answer is forgotten
    Timer {
        interval: 120000
        running: Features.jarvis && mic.state_ === "idle"
        onTriggered: Quickshell.execDetached(["systemctl", "--user", "stop", "jarvis"])
    }

    // no daemon yet, or it restarted: look for its socket now and then,
    // connect once it's there. no socket, no attempt, no error in the log
    Timer {
        interval: 5000
        running: Features.jarvis && !sock.connected
        repeat: true
        triggeredOnStart: true
        onTriggered: probe.running = true
    }

    Process {
        id: probe
        command: ["test", "-S", mic.sockPath]
        onExited: code => {
            if (code === 0 && !sock.connected) {
                sock.connected = false;
                sock.connected = true;
            }
        }
    }
}
