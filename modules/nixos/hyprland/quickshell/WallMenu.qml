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
    // the expanded grid: a fixed column count fills the width exactly (no
    // leftover gap on the right), and the height fits the rows, scrolling
    // once they are more than a screen
    readonly property real tile: 200
    readonly property real tileH: tile * 9 / 16
    readonly property real tileGap: 10
    readonly property real cellW: tile + tileGap
    readonly property real cellH: tileH + 20 + tileGap
    readonly property int columns: Math.max(3, Math.min(8, Math.floor(Math.min((screen?.width ?? 2560) - 80, 1400) / cellW)))
    readonly property real gridW: columns * cellW
    readonly property real gridContentH: Math.min(Math.ceil(count / columns) * cellH, Math.min((screen?.height ?? 1440) - 120, 820))
    // the strip's frame width, the grid's is gridW + 2. the views are laid
    // out at these, not at the frame's own width: the frame is the one that
    // animates, and a hint line that wraps as it grows would move the target
    // with it (and re-flow the tiles every frame)
    readonly property real stripW: stripWidth + 24

    property int current: 0
    // the strip's offset while a step runs, then folded into current
    property real shift: 0
    property int dir: 1
    property bool moving: false
    // the strip, or every video as a grid of tiles
    property bool grid: false
    // the views crossfade: the strip fades out while the frame resizes, the
    // grid fades in behind it, so nothing vanishes and comes back
    property real stripAlpha: 1
    property real gridAlpha: 0
    // d asks to delete the selected video, the next key confirms or keeps
    property bool confirming: false

    function indexOf(name) {
        const i = Wall.files.indexOf(name);
        return i < 0 ? 0 : i;
    }

    // rapid input while a step runs is accumulated, not dropped: a held key
    // or a spun wheel keeps the strip moving instead of losing steps. it
    // drains one cell per settle and is capped so a long hold can't build an
    // endless backlog
    property int queued: 0

    function step(d) {
        if (count === 0)
            return;
        if (moving) {
            queued = Math.max(-6, Math.min(6, queued + d));
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

    // picking keeps the menu open: only esc (or a click outside) closes it,
    // so a few wallpapers can be tried in one go
    function take() {
        if (count > 0)
            Wall.set(Wall.files[current]);
    }

    function takeGrid() {
        if (count > 0 && gridView.currentIndex >= 0)
            Wall.set(Wall.files[gridView.currentIndex]);
    }

    // expand into the grid, on the current wallpaper. the model only fills
    // when the grid is open, so the current index is set a frame after the
    // tiles are built
    function openGrid() {
        grid = true;
        stripAlpha = 0;
        gridAlpha = 1;
        Wall.prefetch();
        gridSettle.start();
    }

    // back to the strip: the grid fades out, the strip fades in as the frame
    // shrinks
    function closeGrid() {
        grid = false;
        gridAlpha = 0;
        stripAlpha = 1;
    }

    // the file the cursor is on, in the strip or the grid
    function selected() {
        if (count === 0)
            return "";
        if (grid)
            return gridView.currentIndex >= 0 ? Wall.files[gridView.currentIndex] : "";
        return Wall.files[current];
    }

    function askDelete() {
        if (selected() === "")
            return;
        confirming = true;
    }

    function cancelDelete() {
        confirming = false;
    }

    // fade the active view out, run the queued action, fade back in. a jump
    // in the strip and a delete hide behind it, so nothing snaps
    property int fadeAction: 0 // 0 none, 1 jump, 2 delete
    property int jumpTarget: 0
    property string deletePath: ""

    function crossfade(action) {
        if (fadeAction !== 0)
            return;
        fadeAction = action;
        if (grid)
            gridView.opacity = 0;
        else
            strip.opacity = 0;
        fadeSwitch.restart();
    }

    function doDelete() {
        const p = selected();
        confirming = false;
        deletePath = p;
        crossfade(2);
    }

    // g to the first (newest), G (shift+g) to the last (oldest), in either view
    function goHome() {
        if (count === 0)
            return;
        if (grid) {
            if (gridView.currentIndex === 0)
                return;
            jumpTarget = 0;
            crossfade(1);
        } else if (current !== 0 || moving || shift !== 0) {
            slide.stop();
            jumpTarget = 0;
            crossfade(1);
        }
    }

    function goEnd() {
        if (count === 0)
            return;
        if (grid) {
            if (gridView.currentIndex === count - 1)
                return;
            jumpTarget = count - 1;
            crossfade(1);
        } else if (current !== count - 1 || moving || shift !== 0) {
            slide.stop();
            jumpTarget = count - 1;
            crossfade(1);
        }
    }

    Component.onCompleted: {
        current = indexOf(Wall.current);
        // a video downloaded since the shell started is in the list too
        Wall.reload();
        takeKeys();
    }

    function takeKeys() {
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

    // the keys stay here until esc or a click outside. hyprland hands them
    // to a window now and then anyway: a pick restarts mpvpaper, its
    // background surface maps again and the keys land on the window under
    // the menu (the same happens in Menu.qml after a bluetooth scan). when
    // they leave quickshell, drop exclusive and take it back: hyprland
    // focuses a layer that turns exclusive
    Connections {
        target: Qt.application

        function onStateChanged() {
            if (Qt.application.state !== Qt.ApplicationActive)
                reclaim.restart();
        }
    }

    Timer {
        id: reclaim
        interval: 100
        onTriggered: {
            if (Qt.application.state === Qt.ApplicationActive)
                return;
            root.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand;
            retake.start();
        }
    }

    // a frame later, two commits
    Timer {
        id: retake
        interval: 50
        onTriggered: {
            root.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive;
            root.takeKeys();
        }
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
            if (root.confirming) {
                if (Kb.key(e, "y") || Kb.key(e, "d") || e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                    root.doDelete();
                else
                    root.cancelDelete();
                e.accepted = true;
                return;
            }
            if (root.grid) {
                if (Kb.key(e, "j") || e.key === Qt.Key_Down)
                    gridView.moveCurrentIndexDown();
                else if (Kb.key(e, "k") || e.key === Qt.Key_Up)
                    gridView.moveCurrentIndexUp();
                else if (Kb.key(e, "l") || e.key === Qt.Key_Right)
                    gridView.moveCurrentIndexRight();
                else if (Kb.key(e, "h") || e.key === Qt.Key_Left)
                    gridView.moveCurrentIndexLeft();
                else if (Kb.key(e, "g") && !(e.modifiers & Qt.ShiftModifier))
                    root.goHome();
                else if (Kb.key(e, "g"))
                    root.goEnd();
                else if (e.key === Qt.Key_Tab)
                    root.closeGrid();
                else if (Kb.key(e, "d"))
                    root.askDelete();
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                    root.takeGrid();
                else if (e.key === Qt.Key_Escape || Kb.key(e, "q"))
                    root.done();
                else
                    return;
                e.accepted = true;
                return;
            }
            if (Kb.key(e, "j") || Kb.key(e, "l") || e.key === Qt.Key_Right || e.key === Qt.Key_Down)
                root.step(1);
            else if (Kb.key(e, "k") || Kb.key(e, "h") || e.key === Qt.Key_Left || e.key === Qt.Key_Up)
                root.step(-1);
            else if (Kb.key(e, "g") && !(e.modifiers & Qt.ShiftModifier))
                root.goHome();
            else if (Kb.key(e, "g"))
                root.goEnd();
            else if (e.key === Qt.Key_Tab)
                root.openGrid();
            else if (Kb.key(e, "d"))
                root.askDelete();
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
        // the size animates on its own properties and lands on whole pixels:
        // a 1px border on a fractional edge shimmers while the box grows
        property real boxW: root.grid ? root.gridW + 2 : root.stripW
        property real boxH: root.grid ? Math.ceil(gridBox.implicitHeight) + 2 : Math.ceil(column.implicitHeight) + 2

        x: Math.round((parent.width - width) / 2)
        // +2 so the content inside the 1px border is exactly columns wide
        width: Math.round(boxW)
        height: Math.round(boxH)
        color: Theme.bg
        border.width: 1
        border.color: Theme.border
        // clip so the growing frame does not let the grid spill over its border
        clip: true
        // the strip and the grid hand off with a smooth resize
        Behavior on boxW {
            NumberAnimation {
                duration: 260
                easing.type: Easing.InOutCubic
            }
        }
        Behavior on boxH {
            NumberAnimation {
                duration: 260
                easing.type: Easing.InOutCubic
            }
        }

        Column {
            id: column
            visible: !root.grid || root.stripAlpha > 0.001
            opacity: root.stripAlpha
            Behavior on opacity {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutQuad
                }
            }
            x: 1
            y: 1
            width: root.stripW - 2
            topPadding: 8
            bottomPadding: 7

            MenuHead {
                width: parent.width
                icon: "\u{f03e}"
                title: "wallpaper"
                status: root.confirming ? `delete ${Wall.base(root.selected())}?` : (root.count === 0 ? "" : Wall.base(Wall.files[root.current] ?? ""))
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
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 120
                        }
                    }

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
                                // the stills are made one at a time, so a card
                                // fades in the first time instead of popping.
                                // a reload keeps it up, no blink
                                property bool shown: false
                                opacity: shown ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: 170
                                        easing.type: Easing.OutQuad
                                    }
                                }
                                onStatusChanged: if (status === Image.Ready) shown = true
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
                hints: root.confirming ? [
                    ["y/d", "delete"],
                    ["esc", "keep"]
                ] : [
                    ["j/k, \u2191\u2193", "move"],
                    ["h/l", "move"],
                    ["g/G", "start/end"],
                    ["enter", "set"],
                    ["d", "delete"],
                    ["tab", "grid"],
                    ["esc", "close"]
                ]
            }
        }

        // the whole folder as tiles, toggled with tab: picking is direct, no
        // need to scroll the strip one by one. the newest are first (wall-list
        // sorts), and anything from the last week is marked "new"
        Column {
            id: gridBox
            visible: root.grid || root.gridAlpha > 0.001
            opacity: root.gridAlpha
            Behavior on opacity {
                NumberAnimation {
                    duration: 180
                    easing.type: Easing.InOutQuad
                }
            }
            x: 1
            y: 1
            width: root.gridW
            topPadding: 8
            bottomPadding: 7

            MenuHead {
                width: parent.width
                icon: "\u{f03e}"
                title: "wallpaper"
                status: root.confirming ? `delete ${Wall.base(root.selected())}?` : `${root.count}`
                font: metrics.font
            }

            GridView {
                id: gridView
                width: parent.width
                height: root.gridContentH
                clip: true
                // the tiles stay while the grid fades out, then the model empties
                model: gridBox.visible ? Wall.files : 0
                cellWidth: root.cellW
                cellHeight: root.cellH
                boundsBehavior: Flickable.StopAtBounds
                Behavior on opacity {
                    NumberAnimation {
                        duration: 120
                    }
                }

                delegate: Item {
                    id: tile
                    required property string modelData
                    required property int index

                    readonly property string name: modelData
                    readonly property string thumbFile: name !== "" ? Wall.thumb(name) : ""
                    property int gen: 0

                    width: gridView.cellWidth
                    height: gridView.cellHeight

                    // the still
                    Rectangle {
                        x: root.tileGap / 2
                        width: root.tile
                        height: root.tileH
                        color: Theme.line

                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            source: tile.thumbFile !== "" ? `file://${tile.thumbFile}?v=${tile.gen}` : ""
                            property bool shown: false
                            opacity: shown ? 1 : 0
                            Behavior on opacity {
                                NumberAnimation {
                                    duration: 170
                                    easing.type: Easing.OutQuad
                                }
                            }
                            onStatusChanged: if (status === Image.Ready) shown = true
                        }

                        // the selected tile gets a border
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            border.width: gridView.currentIndex === tile.index ? 2 : 0
                            border.color: Theme.border
                        }

                        Rectangle {
                            visible: Wall.isNew(tile.name)
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.top: parent.top
                            anchors.topMargin: 4
                            width: newLabel.implicitWidth + 6
                            height: newLabel.implicitHeight + 4
                            color: Theme.selBg
                            radius: 3

                            Text {
                                id: newLabel
                                anchors.centerIn: parent
                                text: "new"
                                color: Theme.bg
                                font.pointSize: 8
                                font.bold: true
                            }
                        }
                    }

                    // the file name under the still
                    Text {
                        y: root.tileH + 4
                        x: root.tileGap / 2
                        width: root.tile
                        text: tile.name !== "" ? Wall.base(tile.name) : ""
                        elide: Text.ElideMiddle
                        horizontalAlignment: Text.AlignHCenter
                        color: gridView.currentIndex === tile.index ? Theme.sel : Theme.dim
                        font: metrics.font
                    }

                    onNameChanged: if (name !== "") Wall.wantThumb(name)

                    Component.onCompleted: if (name !== "") Wall.wantThumb(name)

                    Connections {
                        target: Wall
                        function onThumbReady(path) {
                            if (path === tile.name)
                                tile.gen++;
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            if (tile.index >= 0)
                                Wall.set(tile.name);
                        }
                    }
                }
            }

            KeyHints {
                x: 12
                width: parent.width - 24
                topPadding: 6
                hints: root.confirming ? [
                    ["y/d", "delete"],
                    ["esc", "keep"]
                ] : [
                    ["j/k, \u2191\u2193", "move"],
                    ["h/l", "move"],
                    ["g/G", "start/end"],
                    ["enter", "set"],
                    ["d", "delete"],
                    ["tab", "strip"],
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
                const d = root.queued > 0 ? 1 : -1;
                root.queued -= d;
                root.step(d);
            }
        }
    }

    // the grid's tiles are built on the frame after openGrid, so the cursor
    // lands on the current wallpaper then
    Timer {
        id: gridSettle
        interval: 0
        onTriggered: {
            if (!root.grid)
                return;
            gridView.currentIndex = root.indexOf(Wall.current);
            gridView.positionViewAtIndex(gridView.currentIndex, GridView.Contain);
        }
    }

    // the fade-out of a jump or a delete is over: act, then fade back in
    Timer {
        id: fadeSwitch
        interval: 120
        onTriggered: {
            if (root.fadeAction === 1) {
                if (root.grid) {
                    gridView.currentIndex = root.jumpTarget;
                    gridView.positionViewAtIndex(root.jumpTarget, GridView.Contain);
                } else {
                    root.slide.stop();
                    root.current = root.jumpTarget;
                    root.shift = 0;
                    root.moving = false;
                    root.queued = 0;
                }
            } else if (root.fadeAction === 2) {
                Wall.remove(root.deletePath);
            }
            root.fadeAction = 0;
            if (root.grid)
                gridView.opacity = 1;
            else
                strip.opacity = 1;
        }
    }
}
