import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import qs
import qs.widgets

// the live wallpaper picker: Menu.qml's frame, head and hints, with a strip
// of 5 previews instead of the rows. the middle one is the pick, the strip
// loops (the last file is left of the first), j/k or h/l walk it, enter puts
// the pick on screen, esc closes. the stills come from wall-thumb
PanelWindow {
    id: root

    signal done()

    readonly property int count: Wall.files.length
    // 5 wide, the middle slot is the pick; 7 slots so a step has a cell to
    // slide in from on both sides
    readonly property int mid: 3
    readonly property real cell: Math.min(240, (screen?.width ?? 2560) / 8)
    readonly property real cellHeight: cell * 9 / 16
    // a card that is not the pick is 0.72 of it, and the step is exactly
    // that: they touch, no holes between them
    readonly property real pitch: cell * 0.72
    readonly property real stripWidth: cell * 3.8

    property int current: 0
    // the strip's offset while a step runs, then folded into current
    property real shift: 0
    property int dir: 1
    property bool moving: false

    function indexOf(name) {
        const i = Wall.files.indexOf(name);
        return i < 0 ? 0 : i;
    }

    // the last key pressed while a step runs is taken after it, so a quick
    // scroll does not lose the ones in between
    property int queued: 0

    function step(d) {
        if (count === 0)
            return;
        if (moving) {
            queued = d;
            return;
        }
        moving = true;
        dir = d;
        slide.from = 0;
        slide.to = -d * pitch;
        slide.start();
        // a timer, not the animation's finished: a dropped frame must not
        // leave the strip stuck mid-step
        settle.restart();
    }

    function take() {
        if (count > 0)
            Wall.set(Wall.files[current]);
        done();
    }

    Component.onCompleted: {
        current = indexOf(Wall.current);
        // a video downloaded since the shell started is in the list too
        Wall.reload();
        keyCatcher.forceActiveFocus();
    }

    // the list came back (the reload above): the same file may sit at
    // another index after the new names sorted in
    Connections {
        target: Wall
        function onFilesChanged() {
            root.current = root.indexOf(Wall.current);
            Wall.prefetch();
        }
    }

    color: "transparent"
    implicitHeight: frame.height
    anchors.top: true
    anchors.left: true
    anchors.right: true
    margins.top: 34
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "wall-menu"
    // all keys go here while it is open
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // a click anywhere else closes it
    HyprlandFocusGrab {
        active: true
        windows: [root]
        onCleared: root.done()
    }

    FontMetrics {
        id: metrics
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }

    Item {
        id: keyCatcher
        focus: true
        Keys.onPressed: e => {
            if (Kb.key(e, "j") || Kb.key(e, "l") || e.key === Qt.Key_Right || e.key === Qt.Key_Down)
                root.step(1);
            else if (Kb.key(e, "k") || Kb.key(e, "h") || e.key === Qt.Key_Left || e.key === Qt.Key_Up)
                root.step(-1);
            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                root.take();
            else if (e.key === Qt.Key_Escape || Kb.key(e, "q"))
                root.done();
            else
                return;
            e.accepted = true;
        }
    }

    Rectangle {
        id: frame
        x: (parent.width - width) / 2
        width: root.stripWidth + 24
        height: Math.ceil(column.implicitHeight) + 2
        color: Theme.bg
        border.width: 1
        border.color: Theme.border

        Column {
            id: column
            x: 1
            y: 1
            width: parent.width - 2
            topPadding: 8
            bottomPadding: 7

            MenuHead {
                width: parent.width
                icon: "\u{f03e}"
                title: "wallpaper"
                status: root.count === 0 ? "" : Wall.base(Wall.files[root.current] ?? "")
                font: metrics.font
            }

            // 6px under the head, like the head's own bottom margin
            Item {
                width: parent.width
                height: root.cellHeight + 6

                Item {
                    id: strip
                    x: (parent.width - width) / 2
                    y: 6
                    width: root.stripWidth
                    height: root.cellHeight
                    clip: true

                    Repeater {
                        model: 7

                        delegate: Item {
                            id: slot
                            required property int index

                            readonly property int offset: index - root.mid
                            readonly property int fileIndex: root.count === 0 ? -1 : Wall.wrap(root.current + offset, root.count)
                            readonly property string name: fileIndex >= 0 ? Wall.files[fileIndex] : ""
                            readonly property string thumbFile: fileIndex >= 0 ? Wall.thumb(name) : ""
                            readonly property real dx: offset * root.pitch + root.shift
                            readonly property real distance: Math.abs(dx)
                            property int gen: 0

                            width: root.cell
                            height: root.cellHeight
                            x: strip.width / 2 + dx - width / 2
                            y: 0
                            // the pick is full size, the rest 0.72 of it
                            scale: 1 - 0.28 * Math.min(1, distance / root.pitch)
                            opacity: 1 - 0.12 * Math.min(1, distance / root.pitch)
                            z: -Math.round(distance)

                            Rectangle {
                                anchors.fill: parent
                                color: Theme.line
                            }

                            Image {
                                id: preview
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                source: slot.thumbFile !== "" ? `file://${slot.thumbFile}?v=${slot.gen}` : ""
                            }

                            Rectangle {
                                anchors.fill: parent
                                color: "transparent"
                                border.width: slot.distance < 1 ? 2 : 0
                                border.color: Theme.border
                            }

                            // the still comes from Wall's one-at-a-time queue,
                            // and reloads when it is made
                            onNameChanged: if (name !== "") Wall.wantThumb(name)

                            Component.onCompleted: if (name !== "") Wall.wantThumb(name)

                            Connections {
                                target: Wall
                                function onThumbReady(path) {
                                    if (path === slot.name)
                                        slot.gen++;
                                }
                            }

                            WheelHandler {
                                onWheel: e => root.step(e.angleDelta.y > 0 ? -1 : 1)
                            }

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (slot.offset === 0)
                                        root.take();
                                    else if (slot.fileIndex >= 0)
                                        root.current = slot.fileIndex;
                                }
                            }
                        }
                    }
                }
            }

            KeyHints {
                x: 12
                width: parent.width - 24
                topPadding: 6
                hints: [
                    ["j/k, \u2191\u2193", "move"],
                    ["h/l", "move"],
                    ["enter", "set"],
                    ["esc", "close"]
                ]
            }
        }

    }

    // the step's slide: the strip moves a cell, then the index takes it over
    // and the shift goes back to zero in the same frame, so nothing jumps
    NumberAnimation {
        id: slide
        target: root
        property: "shift"
        duration: 260
        easing.type: Easing.OutCubic
    }

    Timer {
        id: settle
        interval: 300
        onTriggered: {
            root.current = Wall.wrap(root.current + root.dir, root.count);
            root.shift = 0;
            root.moving = false;
            if (root.queued !== 0) {
                const d = root.queued;
                root.queued = 0;
                root.step(d);
            }
        }
    }
}
