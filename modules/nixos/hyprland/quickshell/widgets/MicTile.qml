import QtQuick
import qs

// the jarvis menu's big square, Tile's look: the mic and what jarvis is
// doing. listening: an orange border, a square inside follows the mic.
// working: the icon pulses. speaking: filled orange, bars on the bottom
// edge follow the voice. paused: the mic crossed out, dim. a click pauses
// or resumes. state is jarvis' (mode, not state: Item has a state)
Rectangle {
    id: tile

    property string mode: "idle"
    // 0..1, from the daemon
    property real micLevel: 0
    property real ttsLevel: 0
    property font font

    signal clicked

    readonly property bool listening: mode === "listening"
    readonly property bool working: ["transcribing", "thinking", "searching", "voicing"].includes(mode)
    readonly property bool speaking: mode === "speaking"
    readonly property bool paused: mode === "paused"
    readonly property bool failed: mode === "error"

    color: speaking ? Theme.selBg : mouse.containsMouse ? Theme.hover : "transparent"
    border.width: 1
    border.color: failed ? Theme.urgent : listening || speaking || mouse.containsMouse ? Theme.border : Theme.line
    opacity: 0
    Component.onCompleted: intro.start()

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: 150
        }
    }

    NumberAnimation {
        id: intro
        target: tile
        property: "opacity"
        to: 1
        duration: 160
        easing.type: Easing.OutCubic
    }

    // the mic's level: a square outline that grows from the icon
    Rectangle {
        anchors.centerIn: parent
        visible: tile.listening
        width: 44 + (tile.width - 56) * tile.micLevel
        height: width
        color: "transparent"
        border.width: 1
        border.color: Theme.selBg
        opacity: 0.35 + 0.65 * tile.micLevel
        Behavior on width {
            NumberAnimation {
                duration: 90
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: 90
            }
        }
    }

    Text {
        id: iconText
        anchors.centerIn: parent
        text: tile.paused ? "\u{f036d}" : "\u{f036c}"
        color: tile.speaking ? Theme.sel : tile.failed ? Theme.urgent : tile.paused ? Theme.dim : tile.listening || tile.working ? Theme.selBg : Theme.fg
        font.family: Theme.font
        font.pointSize: 30
        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        SequentialAnimation on opacity {
            running: tile.working
            loops: Animation.Infinite
            onRunningChanged: if (!running)
                iconText.opacity = 1
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
    }

    // the voice: thin bars along the bottom edge, each its own share of the level
    Row {
        id: bars
        visible: tile.speaking
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 2

        readonly property var shape: [0.35, 0.6, 0.85, 1, 0.75, 0.95, 0.6, 0.8, 1, 0.7, 0.9, 0.5, 0.8, 0.65, 0.4, 0.55, 0.9]

        Repeater {
            model: Math.floor((tile.width - 8) / 4)

            delegate: Rectangle {
                required property int index
                anchors.bottom: parent?.bottom
                width: 2
                // the shape turns with every level, so the bars don't move as one
                height: Math.max(1, tile.height * 0.25 * tile.ttsLevel * bars.shape[(index + Math.round(tile.ttsLevel * 7)) % bars.shape.length])
                color: Theme.sel
                Behavior on height {
                    NumberAnimation {
                        duration: 90
                    }
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }
}
