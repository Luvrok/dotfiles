import QtQuick
import Quickshell
import qs
import qs.widgets

// the things to turn on and off (Toggles.qml): a square each, orange while
// it's on, it pulses while it switches. h/l picks a square, enter switches
// it, r restarts it, its own key still works. the menu stays open.
// q goes back to the tools, esc closes
Menu {
    id: menu

    readonly property int columns: Math.min(6, Toggles.list.length)
    property int selected: 0

    title: "switches"
    icon: "\u{f0521}"
    status: Toggles.list.filter(t => Toggles.isOn(t.id)).map(t => t.name).join(" · ")
    statusAccent: true
    lines: 0
    menuWidth: Math.max(ch(40), 26 + columns * ch(12) + (columns - 1) * 10)
    hints: [["h/l", "pick"], ["enter", "on/off"], ["r", "reload"], ["key", "switch"], ...upHint, ["esc", "close"]]

    function move(step) {
        const n = Toggles.list.length;
        selected = (selected + step + n) % n;
    }

    keys: e => {
        if (key(e, "h"))
            move(-1);
        else if (key(e, "l"))
            move(1);
        else if (key(e, "j") || key(e, "k"))
            return true;
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
            Toggles.toggle(Toggles.list[selected]);
        else if (key(e, "r"))
            Toggles.reload(Toggles.list[selected]);
        else {
            const t = Toggles.list.find(t => key(e, t.key));
            if (!t)
                return false;
            selected = Toggles.list.indexOf(t);
            Toggles.toggle(t);
        }
        return true;
    }

    body: Component {
        Flow {
            id: grid

            readonly property real side: menu.ch(12)

            width: parent?.width ?? 0
            leftPadding: 12
            rightPadding: 12
            topPadding: 6
            bottomPadding: 4
            spacing: 10

            Repeater {
                model: Toggles.list

                delegate: Tile {
                    required property var modelData
                    required property int index
                    width: grid.side
                    height: grid.side
                    key: modelData.key
                    icon: modelData.icon
                    name: modelData.name
                    mode: Toggles.mode(modelData.id)
                    selected: menu.selected === index
                    selectedBorder: Theme.fg
                    selectedWidth: 2
                    font: menu.rowFont
                    onClicked: {
                        menu.selected = index;
                        Toggles.toggle(modelData);
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        Toggles.watched = true;
        Toggles.refresh();
        show([]);
    }
    Component.onDestruction: Toggles.watched = false
}
