import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.widgets

// rofi -dmenu in quickshell, drawn like the eww wifi menu
// (home/programs/eww/wifi-menu) out of the parts in widgets/: the head, a
// text line, the rows and the keys. it sits under the bar on the right,
// hyprland slides it in from the right edge and dims the screen around it
// (layer rule for "menu"). a menu in menus/ sets it up and calls show(rows)
// for every page, like a rofi call. rows are things to pick, actions are
// keys. esc or a click outside closes the whole menu, like rofi exiting
// the script
PanelWindow {
    id: root

    // the text line has the keys: a prompt, or a search that filters the
    // rows as you type (case insensitive, every word must match). a menu
    // that opens on its list and is searchable opens it with /, q in an
    // empty search or tab (keeps the filter) goes back to the list. in the
    // list j/k/l and g/G work too. letter keys go by where they are on the
    // keyboard, so they work on the ru layout, and only with the ctrl, alt
    // or super they ask for
    property bool input: false
    property bool searchable: false
    property bool password: false
    // the text line's placeholder
    property string prompt: ""
    // the head, no title no head. busy pulses next to the status while the
    // menu waits for something, keys do nothing then but esc. activity
    // pulses too but keys work
    property string title: ""
    property string icon: ""
    property string status: ""
    property bool statusAccent: false
    // dim text under the head, like what pinentry asks for
    property string note: ""
    property string busy: ""
    property string activity: ""
    // what enter does, the menu's own keys (in the list, or with ctrl or alt
    // in a prompt), and all the keys at the bottom: [[key, what], ...], []
    // hides them
    property string enterHint: "pick"
    property var actions: []
    property var hints: input && !searchable ? [["enter", enterHint], ...(lines > 0 ? [["↑↓", "move"]] : []), ...actions, ["esc", "close"]] : input ? [["enter", enterHint], ["↑↓", "move"], ["tab", "list"], ["q", "back"], ["esc", "close"]] : [["j/k", "move"], ["enter", enterHint], ...actions, ...(searchable ? [["/", "search"]] : []), ["esc", "close"]]
    // rows in the accent color: the connected network, the default sink
    property var active: []
    // in the list when there are no rows
    property string empty: ""
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
    // a menu's own keys, returns true if it took the key. it gets the list's
    // keys, tab and every ctrl, alt or super key
    property var keys: null

    property var rows: []
    property var shown: []
    readonly property alias text: field.text
    readonly property alias rowFont: metrics.font
    // the list for the rows, they have a list property of their own
    readonly property ListView rowsView: list
    // the row under the cursor, -1 for none
    readonly property int current: list.currentIndex >= 0 && list.currentIndex < shown.length ? shown[list.currentIndex] : -1

    // rows made now come in one after another, the ones typing makes don't
    property bool cascading: false

    // index into rows, -1 for the typed text (enter with no match, ctrl+enter)
    signal accepted(int index, string text)
    // backspace in an empty text line or in the list, h in the list
    signal back
    signal cancelled
    // the shell unloads the menu
    signal done

    // a new page
    function show(newRows, selected) {
        rows = newRows;
        busy = "";
        field.input.text = "";
        filter();
        jump(Math.max(0, Math.min(selected ?? 0, shown.length - 1)), 1);
        list.positionViewAtIndex(list.currentIndex, ListView.Contain);
        cascading = true;
        cascadeEnd.restart();
        visible = true;
        takeKeys();
    }

    // the same page with fresh rows, the filter stays. row: the row to keep
    // the cursor on, else it stays where it was
    function update(newRows, row) {
        const at = list.currentIndex;
        rows = newRows;
        filter();
        const pos = row !== undefined ? shown.indexOf(row) : -1;
        jump(Math.max(0, Math.min(pos >= 0 ? pos : at, shown.length - 1)), 1);
    }

    function hide() {
        visible = false;
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

    function openSearch() {
        input = true;
        takeKeys();
    }

    function closeSearch(keep) {
        input = false;
        if (!keep) {
            field.input.text = "";
            filter();
        }
        takeKeys();
    }

    function takeKeys() {
        if (input)
            field.input.forceActiveFocus();
        else
            keyCatcher.forceActiveFocus();
    }

    // width in characters, like rofi's ch
    function ch(n) {
        return Math.ceil(metrics.averageCharacterWidth * n);
    }

    function filter() {
        const words = field.text.toLowerCase().split(/\s+/).filter(w => w !== "");
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
        if (busy !== "" || !visible)
            return;
        if (shown.length > 0) {
            if (!divider(list.currentIndex))
                accepted(shown[list.currentIndex], rows[shown[list.currentIndex]]);
        } else if (input)
            accepted(-1, field.text);
    }

    // xkb keycodes of the us keys
    readonly property var codes: ({ "/": 61, a: 38, c: 54, d: 40, e: 26, g: 42, h: 43, j: 44, k: 45, l: 46, m: 58, n: 57, o: 32, p: 33, q: 24, r: 27, s: 39, t: 28, u: 30, v: 55, w: 25 })

    // a key by its us name, on any layout. mods: the ctrl, alt and super it
    // needs, shift doesn't matter
    function key(e, name, mods) {
        if ((e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== (mods ?? Qt.NoModifier))
            return false;
        return e.key === (name === "/" ? Qt.Key_Slash : Qt["Key_" + name.toUpperCase()]) || e.nativeScanCode === codes[name];
    }

    function handleKey(e) {
        const k = e.key;
        e.accepted = true;
        if (!visible)
            return;
        if (k === Qt.Key_Escape) {
            cancel();
            return;
        }
        if (busy !== "")
            return;
        const mods = e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier);
        // tab types nothing, a prompt's menu may take it
        if (keys && (!input || mods || k === Qt.Key_Tab) && keys(e))
            return;
        const ctrl = Qt.ControlModifier;
        const enter = k === Qt.Key_Return || k === Qt.Key_Enter;
        if (k === Qt.Key_PageUp)
            move(-lines, false);
        else if (k === Qt.Key_PageDown)
            move(lines, false);
        else if (input) {
            if (enter && (mods & ctrl))
                accepted(-1, field.text);
            else if (enter || key(e, "m", ctrl))
                accept();
            else if (k === Qt.Key_Up || key(e, "p", ctrl) || key(e, "k", ctrl))
                move(-1, true);
            else if (k === Qt.Key_Down || key(e, "n", ctrl) || key(e, "j", ctrl))
                move(1, true);
            else if (searchable && k === Qt.Key_Tab)
                closeSearch(true);
            else if (searchable && field.text === "" && key(e, "q"))
                closeSearch(false);
            else if (k === Qt.Key_Backspace && field.text === "")
                back();
            else if (key(e, "a", ctrl))
                field.input.cursorPosition = 0;
            else if (key(e, "e", ctrl))
                field.input.cursorPosition = field.text.length;
            else if (key(e, "u", ctrl)) {
                field.input.remove(0, field.input.cursorPosition);
                filter();
            } else if (key(e, "w", ctrl)) {
                field.input.text = "";
                filter();
            } else if (key(e, "h", ctrl)) {
                field.input.remove(field.input.cursorPosition - 1, field.input.cursorPosition);
                filter();
            } else
                e.accepted = false;
            return;
        }
        if (enter || key(e, "l"))
            accept();
        else if (k === Qt.Key_Up || key(e, "k"))
            move(-1, true);
        else if (k === Qt.Key_Down || key(e, "j"))
            move(1, true);
        else if (k === Qt.Key_Home || (key(e, "g") && !(e.modifiers & Qt.ShiftModifier)))
            jump(0, 1);
        else if (k === Qt.Key_End || key(e, "g"))
            jump(shown.length - 1, -1);
        else if (searchable && key(e, "/"))
            openSearch();
        else if (key(e, "q") && field.text !== "")
            closeSearch(false);
        else if (k === Qt.Key_Backspace || key(e, "h"))
            back();
    }

    visible: false
    color: "transparent"
    // whole pixels, a fraction would cut off the bottom border
    implicitWidth: Math.ceil(menuWidth)
    implicitHeight: frame.height

    anchors.top: location === "top" || location === "top-right"
    anchors.right: location === "top-right" || location === "right"
    // 10px under the 24px bar and from the right edge
    margins.top: location === "top" || location === "top-right" ? 34 : 0
    margins.right: location === "top-right" || location === "right" ? 10 : 0

    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "menu"
    // all keys go here while it's open
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    // a click anywhere else closes it
    HyprlandFocusGrab {
        active: root.visible
        windows: [root]
        onCleared: root.cancel()
    }

    // the keys stay here until esc or a click outside. hyprland hands them
    // to a window now and then anyway (after bluetooth on, a scan), so when
    // they leave quickshell, drop exclusive and take it back: hyprland
    // focuses a layer that turns exclusive. the askpass menu on top keeps
    // quickshell active, so they don't fight
    Connections {
        target: Qt.application
        function onStateChanged() {
            if (root.visible && Qt.application.state !== Qt.ApplicationActive)
                reclaim.restart();
        }
    }

    // a click outside closes the menu first
    Timer {
        id: reclaim
        interval: 100
        onTriggered: {
            if (!root.visible || Qt.application.state === Qt.ApplicationActive)
                return;
            root.WlrLayershell.keyboardFocus = WlrKeyboardFocus.OnDemand;
            retake.start();
        }
    }

    // a frame later, two commits
    Timer {
        id: retake
        interval: 50
        onTriggered: root.WlrLayershell.keyboardFocus = WlrKeyboardFocus.Exclusive
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

    Rectangle {
        id: frame
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
            bottomPadding: root.hints.length > 0 ? 7 : 0

            MenuHead {
                visible: root.title !== ""
                width: parent.width
                icon: root.icon
                title: root.title
                status: root.status
                statusAccent: root.statusAccent
                pulse: root.busy !== "" ? root.busy : root.activity
                centered: root.align === Text.AlignHCenter
                font: metrics.font
            }

            Text {
                visible: root.note !== ""
                x: 12
                width: parent.width - 24
                bottomPadding: 6
                text: root.note
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Theme.dim
                font: metrics.font
            }

            SearchField {
                id: field
                width: parent.width
                open: root.input
                placeholder: root.prompt
                count: root.lines > 0 && root.rows.length > 0 ? `${root.shown.length}/${root.rows.length}` : ""
                password: root.password
                font: metrics.font
                onEdited: root.filter()
                onPressed: e => root.handleKey(e)
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

                delegate: MenuRow {
                    menu: root
                    list: root.rowsView
                }

                Text {
                    anchors.centerIn: parent
                    visible: list.count === 0
                    text: root.rows.length > 0 ? "nothing found" : root.empty
                    color: Theme.dim
                    font: metrics.font
                    opacity: visible ? 1 : 0
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 200
                        }
                    }
                }

                Rectangle {
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

            KeyHints {
                visible: root.hints.length > 0
                x: 12
                width: parent.width - 24
                topPadding: 6
                hints: root.hints
            }
        }
    }
}
