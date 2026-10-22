import QtQuick
import Quickshell
import qs
import qs.widgets

// the things to turn on and off (Toggles.qml): a square each, orange while
// it's on, it pulses while it switches. its key or a click switches it,
// the menu stays open. q goes back to the tools, esc closes
Menu {
    id: menu

    readonly property int columns: Math.min(6, Toggles.list.length)

    title: "switches"
    icon: "\u{f0521}"
    status: Toggles.list.filter(t => Toggles.isOn(t.id)).map(t => t.name).join(" · ")
    statusAccent: true
    lines: 0
    menuWidth: Math.max(ch(40), 26 + columns * ch(12) + (columns - 1) * 10)
    hints: [["key", "switch"], ...upHint, ["esc", "close"]]

    keys: e => {
        const t = Toggles.list.find(t => key(e, t.key));
        if (!t)
            return false;
        Toggles.toggle(t);
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
                    width: grid.side
                    height: grid.side
                    key: modelData.key
                    icon: modelData.icon
                    name: modelData.name
                    mode: Toggles.mode(modelData.id)
                    font: menu.rowFont
                    onClicked: Toggles.toggle(modelData)
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
