import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

// the idle screensaver: the same video as the wallpaper, on the top layer so
// it covers the windows, under a transparent layer that takes the keys and
// the pointer, so any input ends it. Wall.qml pauses the wallpaper while it
// runs; the clock and the lock are not involved (it is not a lock screen)
Scope {
    id: root

    required property ShellScreen screen

    readonly property bool on: Wall.screensaver && !Wall.locked && Wall.file !== ""

    Process {
        id: paper
        running: root.on
        command: [
            "mpvpaper", "-l", "top",
            "-o", "no-config loop no-audio no-resume-playback panscan=1 hwdec=auto-safe quiet",
            root.screen.name,
            Wall.file
        ]
    }

    PanelWindow {
        id: cover

        visible: root.on
        screen: root.screen
        color: "transparent"
        anchors.top: true
        anchors.bottom: true
        anchors.left: true
        anchors.right: true
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "screensaver"
        // all keys go here while the screensaver shows
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

        onVisibleChanged: if (visible) keys.forceActiveFocus()

        Component.onCompleted: if (visible) keys.forceActiveFocus()

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                Wall.screensaver = false;
                e.accepted = true;
            }
        }

        // any movement, click or scroll is "the user is back"
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: Wall.screensaver = false
            onClicked: Wall.screensaver = false
            onWheel: Wall.screensaver = false
        }
    }
}
