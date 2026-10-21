import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// rofi -dmenu in quickshell, drawn like the eww wifi menu
// (home/programs/eww/wifi-menu): title and status on top, the rows, a key
// hint below. it slides down from under the bar on the right, the rows come
// in one after another and the cursor glides. a menu in menus/ sets it up
// and calls show(rows) for every page, like a rofi call. rows are things to
// pick, actions are keys. "name\tinfo" puts info in a dim column on the
// right, "" is a divider. esc or a click outside closes the whole menu, like
// rofi exiting the script
PanelWindow {
    id: root

    // with an entry the rows filter as you type (case insensitive, every word
    // must match). without one j/k/l/q and g/G work too. letter keys go by
    // where they are on the keyboard, so they work on the ru layout too
    property bool input: true
    property bool password: false
    // the entry's placeholder
    property string prompt: ""
    // the head, no title no head. busy pulses next to the status while the
    // menu waits for something, keys do nothing then but esc
    property string title: ""
    // a nerd font glyph before the title
    property string icon: ""
    property string status: ""
    property string busy: ""
    property string hint: input ? "enter pick  esc close" : "j/k move  enter pick  esc close"
    // rows in the accent color: the connected network, the default sink
    property var active: []
    // "top-right" or "top" under the bar, "center", "right"
    property string location: "top-right"
    property real menuWidth: 520
    // list height in rows, 0 hides the list
    property int lines: 10
    property int padV: 3
    property int padH: 12
    property int align: Text.AlignLeft
    property string fontFamily: Theme.font
    property int fontSize: Theme.fontSize
    // a menu's own keys (translate's alt binds), returns true if it took the key
    property var keys: null

    property var rows: []
    property var shown: []
    readonly property alias text: entry.text
    // the row under the cursor, -1 for none
    readonly property int current: list.currentIndex >= 0 && list.currentIndex < shown.length ? shown[list.currentIndex] : -1
    // an entry counts what the filter left
    readonly property string statusText: status !== "" ? status : input && rows.length > 0 ? `${shown.length}/${rows.length}` : ""

    // 0..1 while it slides in or out
    property real reveal: 0
    property bool closing: false
    // rows made now come in one after another, the ones typing makes don't
    property bool cascading: false

    // index into rows, -1 for the typed text (enter with no match, ctrl+enter)
    signal accepted(int index, string text)
    // backspace in an empty entry
    signal back
    signal cancelled
    // the shell unloads the menu
    signal done

    function show(newRows, selected) {
        rows = newRows;
        busy = "";
        entry.text = "";
        filter();
        jump(Math.max(0, Math.min(selected ?? 0, shown.length - 1)), 1);
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
        cascading = true;
        cascadeEnd.restart();
        if (!visible || closing) {
            slideOut.stop();
            closing = false;
            visible = true;
            slideIn.restart();
        }
        if (input)
            entry.forceActiveFocus();
        else
            keyCatcher.forceActiveFocus();
    }

    function hide() {
        if (!visible || closing)
            return;
        slideIn.stop();
        closing = true;
        slideOut.restart();
    }

    // stay open and pulse while something runs, show() ends it
    function wait(label) {
        busy = label;
    }

    function cancel() {
        hide();
        cancelled();
        done();
    }

    // width in characters, like rofi's ch
    function ch(n) {
        return Math.ceil(metrics.averageCharacterWidth * n);
    }

    function filter() {
        const words = entry.text.toLowerCase().split(/\s+/).filter(w => w !== "");
        const out = [];
        for (let i = 0; i < rows.length; i++) {
            const row = rows[i].toLowerCase();
            if (words.every(w => row.includes(w)))
                out.push(i);
        }
        shown = out;
        list.currentIndex = 0;
    }

    function divider(i) {
        return rows[shown[i]] === "";
    }

    // step over dividers, wrap or stop at the ends
    function move(step, wrap) {
        const n = shown.length;
        if (n === 0)
            return;
        const dir = step < 0 ? -1 : 1;
        let i = list.currentIndex + step;
        for (let k = 0; k <= n; k++) {
            i = wrap ? (i % n + n) % n : Math.max(0, Math.min(i, n - 1));
            if (!divider(i)) {
                list.currentIndex = i;
                return;
            }
            i += dir;
        }
    }

    function jump(i, dir) {
        list.currentIndex = i;
        if (shown.length > 0 && divider(i))
            move(dir, false);
    }

    function accept() {
        if (busy !== "" || closing)
            return;
        if (shown.length > 0) {
            if (!divider(list.currentIndex))
                accepted(shown[list.currentIndex], rows[shown[list.currentIndex]]);
        } else if (input)
            accepted(-1, entry.text);
    }

    // xkb keycodes of the us letters
    readonly property var codes: ({ a: 38, c: 54, d: 40, e: 26, g: 42, h: 43, j: 44, k: 45, l: 46, m: 58, n: 57, o: 32, p: 33, q: 24, r: 27, s: 39, t: 28, u: 30, v: 55, w: 25 })

    // a letter key by its us name, on any layout
    function key(e, letter) {
        return e.key === Qt["Key_" + letter.toUpperCase()] || e.nativeScanCode === codes[letter];
    }

    function handleKey(e) {
        const k = e.key;
        e.accepted = true;
        if (closing)
            return;
        if (k === Qt.Key_Escape || (!input && key(e, "q"))) {
            cancel();
            return;
        }
        if (busy !== "")
            return;
        if (keys && keys(e))
            return;
        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
        const shift = (e.modifiers & Qt.ShiftModifier) !== 0;
        const enter = k === Qt.Key_Return || k === Qt.Key_Enter;
        if (enter && ctrl && input)
            accepted(-1, entry.text);
        else if (enter || (ctrl && key(e, "m")) || (!input && key(e, "l")))
            accept();
        else if (k === Qt.Key_Up || (ctrl && (key(e, "p") || key(e, "k"))) || (!input && key(e, "k")))
            move(-1, true);
        else if (k === Qt.Key_Down || (ctrl && (key(e, "n") || key(e, "j"))) || (!input && key(e, "j")))
            move(1, true);
        else if (k === Qt.Key_PageUp)
            move(-lines, false);
        else if (k === Qt.Key_PageDown)
            move(lines, false);
        else if (k === Qt.Key_Home || (!input && key(e, "g") && !shift))
            jump(0, 1);
        else if (k === Qt.Key_End || (!input && key(e, "g")))
            jump(shown.length - 1, -1);
        else if (input && k === Qt.Key_Backspace && entry.text === "")
            back();
        else if (input && ctrl && key(e, "a"))
            entry.cursorPosition = 0;
        else if (input && ctrl && key(e, "e"))
            entry.cursorPosition = entry.text.length;
        else if (input && ctrl && key(e, "u"))
            entry.remove(0, entry.cursorPosition);
        else if (input && ctrl && key(e, "w"))
            entry.text = "";
        else if (input && ctrl && key(e, "h"))
            entry.remove(entry.cursorPosition - 1, entry.cursorPosition);
        else
            e.accepted = false;
    }

    visible: false
    color: "transparent"
    // whole pixels, a fraction would cut off the bottom border
    implicitWidth: Math.ceil(menuWidth)
    implicitHeight: frame.height

    anchors.top: location === "top" || location === "top-right"
    anchors.right: location === "top-right" || location === "right"
    // under the 24px bar, like y-offset in the rasi files
    margins.top: location === "top" || location === "top-right" ? 33 : 0
    margins.right: location === "top-right" ? 5 : location === "right" ? 40 : 0

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "menu"
    // let go of the keyboard at once, pinentry may want it
    WlrLayershell.keyboardFocus: closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

    // a click anywhere else closes it
    HyprlandFocusGrab {
        active: root.visible && !root.closing
        windows: [root]
        onCleared: {
            if (!root.closing)
                root.cancel();
        }
    }

    NumberAnimation {
        id: slideIn
        target: root
        property: "reveal"
        to: 1
        duration: 220
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: slideOut
        NumberAnimation {
            target: root
            property: "reveal"
            to: 0
            duration: 120
            easing.type: Easing.InCubic
        }
        ScriptAction {
            script: {
                root.visible = false;
                root.closing = false;
            }
        }
    }

    Timer {
        id: cascadeEnd
        interval: 200
        onTriggered: root.cascading = false
    }

    FontMetrics {
        id: metrics
        font.family: root.fontFamily
        font.pointSize: root.fontSize
    }

    Item {
        id: keyCatcher
        focus: !root.input
        Keys.onPressed: e => root.handleKey(e)
    }

    // slides down like an eww revealer: the panel moves out from under its
    // top edge while it shows more of itself
    Item {
        width: parent.width
        height: frame.height * root.reveal
        clip: true
        opacity: root.reveal

        Rectangle {
            id: frame
            y: parent.height - height
            width: parent.width
            height: Math.ceil(column.implicitHeight) + 2
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            Column {
                id: column
                x: 1
                y: 1
                width: parent.width - 2
                topPadding: root.title !== "" || root.input ? 8 : 0
                bottomPadding: root.hint !== "" ? 8 : 0

                // title, busy, status
                Item {
                    visible: root.title !== ""
                    width: parent.width
                    height: titleText.implicitHeight + 6

                    // centered rows get a centered title
                    Text {
                        id: titleText
                        x: root.align === Text.AlignHCenter && root.statusText === "" && root.busy === "" ? (parent.width - implicitWidth) / 2 : 12
                        text: root.icon !== "" ? `${root.icon}  ${root.title}` : root.title
                        color: Theme.selBg
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize
                        font.bold: true
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        spacing: 8

                        Text {
                            id: busyText
                            visible: root.busy !== ""
                            text: root.busy
                            color: Theme.dim
                            font: metrics.font

                            SequentialAnimation on opacity {
                                running: busyText.visible
                                loops: Animation.Infinite
                                NumberAnimation {
                                    to: 0.3
                                    duration: 600
                                    easing.type: Easing.InOutSine
                                }
                                NumberAnimation {
                                    to: 1
                                    duration: 600
                                    easing.type: Easing.InOutSine
                                }
                            }
                        }

                        Text {
                            width: Math.min(implicitWidth, column.width - titleText.implicitWidth - 48 - (busyText.visible ? busyText.implicitWidth + 8 : 0))
                            text: root.statusText
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.dim
                            font: metrics.font
                        }
                    }
                }

                // the entry, a dark strip with an orange line under it
                Item {
                    visible: root.input
                    width: parent.width
                    height: entryBox.height + (list.visible ? 6 : 0)

                    Rectangle {
                        id: entryBox
                        x: 12
                        width: parent.width - 24
                        height: entry.implicitHeight + 8
                        color: Theme.line

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: parent.width
                            height: 1
                            color: Theme.selBg
                        }

                        Text {
                            x: 6
                            width: parent.width - 12
                            anchors.verticalCenter: parent.verticalCenter
                            visible: entry.text === ""
                            text: root.prompt
                            textFormat: Text.PlainText
                            elide: Text.ElideRight
                            color: Theme.dim
                            font: metrics.font
                        }

                        TextInput {
                            id: entry
                            x: 6
                            width: parent.width - 12
                            anchors.verticalCenter: parent.verticalCenter
                            focus: root.input
                            clip: true
                            color: Theme.fg
                            selectionColor: Theme.selBg
                            selectedTextColor: Theme.sel
                            font: metrics.font
                            echoMode: root.password ? TextInput.Password : TextInput.Normal
                            passwordCharacter: "•"
                            onTextEdited: root.filter()
                            Keys.onPressed: e => root.handleKey(e)
                        }
                    }
                }

                ListView {
                    id: list
                    visible: root.lines > 0
                    width: parent.width
                    height: root.lines * rowHeight
                    clip: true
                    model: root.shown
                    boundsBehavior: Flickable.StopAtBounds

                    // the cursor glides from row to row
                    highlight: Rectangle {
                        color: Theme.selBg
                        opacity: list.currentItem?.opacity ?? 1
                    }
                    highlightMoveDuration: 90
                    highlightMoveVelocity: -1
                    highlightResizeDuration: 0

                    readonly property real rowHeight: Math.ceil(metrics.height) + 2 * root.padV

                    delegate: Item {
                        id: row

                        required property int index
                        required property int modelData
                        readonly property string raw: root.rows[modelData] ?? ""
                        readonly property int tab: raw.indexOf("\t")
                        readonly property bool isDivider: raw === ""
                        readonly property bool selected: ListView.isCurrentItem
                        readonly property bool accent: root.active.includes(modelData)

                        width: list.width
                        height: list.rowHeight
                        transform: Translate {
                            id: shift
                        }

                        Component.onCompleted: {
                            if (!root.cascading)
                                return;
                            opacity = 0;
                            shift.y = -6;
                            intro.start();
                        }

                        SequentialAnimation {
                            id: intro
                            PauseAnimation {
                                duration: Math.min(row.index, 12) * 22
                            }
                            ParallelAnimation {
                                NumberAnimation {
                                    target: row
                                    property: "opacity"
                                    to: 1
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                                NumberAnimation {
                                    target: shift
                                    property: "y"
                                    to: 0
                                    duration: 160
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: mouse.containsMouse && !row.selected && !row.isDivider
                            color: Theme.hover
                        }

                        Rectangle {
                            visible: row.isDivider
                            x: root.padH
                            width: parent.width - 2 * root.padH
                            height: 1
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.line
                        }

                        Text {
                            id: info
                            visible: !row.isDivider && row.tab >= 0
                            anchors.right: parent.right
                            anchors.rightMargin: root.padH + (scrollbar.visible ? 4 : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.tab >= 0 ? row.raw.slice(row.tab + 1) : ""
                            textFormat: Text.PlainText
                            color: row.selected ? Theme.sel : Theme.dim
                            font: metrics.font
                            Behavior on color {
                                ColorAnimation {
                                    duration: 90
                                }
                            }
                        }

                        Text {
                            visible: !row.isDivider
                            anchors.left: parent.left
                            anchors.leftMargin: root.padH
                            anchors.right: info.visible ? info.left : parent.right
                            anchors.rightMargin: info.visible ? 12 : root.padH + (scrollbar.visible ? 4 : 0)
                            anchors.verticalCenter: parent.verticalCenter
                            horizontalAlignment: root.align
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: row.tab >= 0 ? row.raw.slice(0, row.tab) : row.raw
                            color: row.selected ? Theme.sel : row.accent ? Theme.selBg : Theme.fg
                            font: metrics.font
                            Behavior on color {
                                ColorAnimation {
                                    duration: 90
                                }
                            }
                        }

                        // click selects, double click picks, like rofi
                        MouseArea {
                            id: mouse
                            anchors.fill: parent
                            enabled: !row.isDivider
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: list.currentIndex = row.index
                            onDoubleClicked: {
                                list.currentIndex = row.index;
                                root.accept();
                            }
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: list.count === 0 && root.rows.length > 0
                        text: "nothing found"
                        color: Theme.dim
                        font: metrics.font
                    }

                    Rectangle {
                        id: scrollbar
                        visible: list.contentHeight > list.height + 1
                        anchors.right: parent.right
                        anchors.rightMargin: 2
                        width: 2
                        height: parent.height
                        color: "transparent"

                        Rectangle {
                            width: parent.width
                            height: Math.max(12, parent.height * list.visibleArea.heightRatio)
                            y: parent.height * list.visibleArea.yPosition
                            color: Theme.selBg
                            opacity: 0.7
                        }
                    }
                }

                Text {
                    visible: root.hint !== ""
                    width: parent.width
                    leftPadding: 12
                    rightPadding: 12
                    topPadding: 6
                    text: root.hint
                    wrapMode: Text.WordWrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: Theme.dim
                    font.family: root.fontFamily
                    font.pointSize: 8
                }
            }
        }
    }
}
