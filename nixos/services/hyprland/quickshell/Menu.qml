import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// rofi -dmenu in quickshell, looks like home/programs/rofi/config. a menu in
// menus/ sets it up and calls show(rows) for every page, like a rofi call.
// esc or a click outside closes the whole menu, like rofi exiting the script
PanelWindow {
    id: root

    // with an entry the rows filter as you type (case insensitive, every word
    // must match). without one j/k/l/q work too, like the rasi files without
    // an inputbar
    property bool input: true
    property bool password: false
    // left of the entry, only prompts without rows show it
    property string prompt: ""
    // "center", "top-right" under the bar, "right"
    property string location: "center"
    property real menuWidth: 520
    // list height in rows, 0 shows the entry alone
    property int lines: 10
    property int padV: 2
    property int padH: 4
    property int align: Text.AlignLeft
    property string fontFamily: Theme.font
    property int fontSize: Theme.fontSize
    // rows with an entry keep their text color, like rofi-pass.rasi
    property color selFg: input ? Theme.fg : Theme.sel
    // a menu's own keys (translate's alt binds), returns true if it took the key
    property var keys: null

    property var rows: []
    property var shown: []
    readonly property alias text: entry.text

    // index into rows, -1 for the typed text (enter with no match, ctrl+enter)
    signal accepted(int index, string text)
    signal cancelled
    // the shell unloads the menu
    signal done

    function show(newRows, selected) {
        rows = newRows;
        entry.text = "";
        filter();
        list.currentIndex = Math.max(0, Math.min(selected ?? 0, shown.length - 1));
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
        visible = true;
        if (input)
            entry.forceActiveFocus();
        else
            keyCatcher.forceActiveFocus();
    }

    function hide() {
        visible = false;
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

    function move(step, wrap) {
        const n = shown.length;
        if (n === 0)
            return;
        let i = list.currentIndex + step;
        i = wrap ? (i + n) % n : Math.max(0, Math.min(i, n - 1));
        list.currentIndex = i;
    }

    function accept() {
        if (shown.length > 0)
            accepted(shown[list.currentIndex], rows[shown[list.currentIndex]]);
        else if (input)
            accepted(-1, entry.text);
    }

    function handleKey(e) {
        if (keys && keys(e)) {
            e.accepted = true;
            return;
        }
        const k = e.key;
        const ctrl = (e.modifiers & Qt.ControlModifier) !== 0;
        const enter = k === Qt.Key_Return || k === Qt.Key_Enter;
        if (k === Qt.Key_Escape || (!input && k === Qt.Key_Q))
            cancel();
        else if (enter && ctrl && input)
            accepted(-1, entry.text);
        else if (enter || (ctrl && k === Qt.Key_M) || (!input && k === Qt.Key_L))
            accept();
        else if (k === Qt.Key_Up || (ctrl && (k === Qt.Key_P || k === Qt.Key_K)) || (!input && k === Qt.Key_K))
            move(-1, true);
        else if (k === Qt.Key_Down || (ctrl && (k === Qt.Key_N || k === Qt.Key_J)) || (!input && k === Qt.Key_J))
            move(1, true);
        else if (k === Qt.Key_PageUp)
            move(-lines, false);
        else if (k === Qt.Key_PageDown)
            move(lines, false);
        else if (input && ctrl && k === Qt.Key_A)
            entry.cursorPosition = 0;
        else if (input && ctrl && k === Qt.Key_E)
            entry.cursorPosition = entry.text.length;
        else if (input && ctrl && k === Qt.Key_U)
            entry.remove(0, entry.cursorPosition);
        else if (input && ctrl && k === Qt.Key_W)
            entry.text = "";
        else if (input && ctrl && k === Qt.Key_H)
            entry.remove(entry.cursorPosition - 1, entry.cursorPosition);
        else
            return;
        e.accepted = true;
    }

    visible: false
    color: "transparent"
    implicitWidth: menuWidth
    implicitHeight: frame.implicitHeight

    anchors.top: location === "top-right"
    anchors.right: location === "top-right" || location === "right"
    // 10px under the 24px bar, like y-offset in the rasi files
    margins.top: location === "top-right" ? 33 : 0
    margins.right: location === "top-right" ? 5 : location === "right" ? 40 : 0

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "menu"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // a click anywhere else closes it
    HyprlandFocusGrab {
        active: root.visible
        windows: [root]
        onCleared: root.cancel()
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

    Rectangle {
        id: frame
        anchors.fill: parent
        implicitHeight: column.implicitHeight + 2
        color: Theme.bg
        border.width: 1
        border.color: Theme.border

        Column {
            id: column
            x: 1
            y: 1
            width: parent.width - 2

            // inputbar
            Item {
                visible: root.input
                width: parent.width
                height: entry.implicitHeight + 2 * root.padV + (list.visible ? 1 : 0)

                Text {
                    id: promptLabel
                    visible: root.prompt !== "" && !list.visible
                    x: 8
                    y: root.padV
                    text: root.prompt
                    color: Theme.fg
                    font: metrics.font
                }

                Rectangle {
                    visible: promptLabel.visible
                    x: promptLabel.x + promptLabel.implicitWidth + 8
                    width: 1
                    height: parent.height
                    color: Theme.border
                }

                TextInput {
                    id: entry
                    x: promptLabel.visible ? promptLabel.x + promptLabel.implicitWidth + 17 : root.padH
                    y: root.padV
                    width: parent.width - x - root.padH
                    focus: root.input
                    clip: true
                    color: Theme.fg
                    selectionColor: Theme.selBg
                    selectedTextColor: Theme.sel
                    font: metrics.font
                    echoMode: root.password ? TextInput.Password : TextInput.Normal
                    passwordCharacter: "*"
                    onTextEdited: root.filter()
                    Keys.onPressed: e => root.handleKey(e)
                }

                // the line between the entry and the list
                Rectangle {
                    visible: list.visible
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 1
                    color: Theme.border
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
                highlightMoveDuration: 0

                readonly property real rowHeight: metrics.height + 2 * root.padV

                delegate: Rectangle {
                    required property int index
                    required property int modelData
                    readonly property bool selected: index === list.currentIndex

                    width: list.width
                    height: list.rowHeight
                    color: selected ? Theme.selBg : "transparent"

                    Text {
                        anchors.fill: parent
                        anchors.leftMargin: root.padH
                        anchors.rightMargin: root.padH + (scrollbar.visible ? scrollbar.width : 0)
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: root.align
                        elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: root.rows[parent.modelData] ?? ""
                        color: parent.selected ? root.selFg : Theme.fg
                        font: metrics.font
                    }

                    // click selects, double click picks, like rofi
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: list.currentIndex = parent.index
                        onDoubleClicked: {
                            list.currentIndex = parent.index;
                            root.accept();
                        }
                    }
                }

                Rectangle {
                    id: scrollbar
                    visible: list.contentHeight > list.height
                    anchors.right: parent.right
                    width: 4
                    height: parent.height
                    color: "transparent"

                    Rectangle {
                        width: parent.width
                        height: Math.max(8, parent.height * list.visibleArea.heightRatio)
                        y: parent.height * list.visibleArea.yPosition
                        color: Theme.fg
                    }
                }
            }
        }
    }
}
