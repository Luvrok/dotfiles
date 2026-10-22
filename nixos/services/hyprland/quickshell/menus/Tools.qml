import QtQuick
import Quickshell
import qs
import qs.widgets

// the small tools behind one key ($mod+a): big squares, each with the key
// that opens it in the corner. a tool with a menu opens in its place and
// q goes back here, the others just run. esc closes, a click works too
Menu {
    id: menu

    // menu: opens that menu, run: a command
    readonly property var tools: [
        {
            key: "e",
            name: "emoji",
            icon: "\u{f01f5}",
            menu: "emoji"
        },
        {
            key: "c",
            name: "calc",
            icon: "\u{f00ec}",
            menu: "calc"
        },
        {
            key: "p",
            name: "color",
            icon: "\u{f020a}",
            run: 'c=$(hyprpicker -f hex) && [ -n "$c" ] && printf %s "$c" | wl-copy && notify-send -a color "$c" "copied"'
        },
        {
            key: "o",
            name: "ocr",
            icon: "\u{f113a}",
            run: 'g=$(slurp) && grim -g "$g" - | tesseract -l eng+rus stdin stdout 2>/dev/null | wl-copy && notify-send OCR "Text copied"'
        },
        {
            key: "t",
            name: "translate",
            icon: "\u{f05ca}",
            menu: "translate"
        },
        {
            key: "m",
            name: "player",
            icon: "\u{f075a}",
            menu: "player"
        },
        {
            key: "u",
            name: "systemd",
            icon: "\u{f08d6}",
            menu: "units"
        },
        {
            key: "v",
            name: "switches",
            icon: "\u{f0521}",
            menu: "switches"
        },
        {
            key: "s",
            name: "shot",
            icon: "\u{f0e51}",
            // after the menu has slid away
            run: "sleep 0.3; qs -c hyprland ipc call shot take"
        }
    ]

    function pick(t) {
        if (t.menu) {
            goTo(t.menu);
            return;
        }
        hide();
        // a moment for the menu to go, slurp and the picker want the screen
        Quickshell.execDetached(["sh", "-c", `sleep 0.2; ${t.run}`]);
        done();
    }

    title: "tools"
    icon: "\u{f09ad}"
    lines: 0
    // up to 6 squares in a row
    readonly property int columns: Math.min(6, tools.length)
    menuWidth: 26 + columns * ch(12) + (columns - 1) * 10
    hints: [["key", "open"], ["q", "back in a tool"], ["esc", "close"]]

    keys: e => {
        const t = tools.find(t => key(e, t.key));
        if (!t)
            return false;
        pick(t);
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
                model: menu.tools

                delegate: Tile {
                    required property var modelData
                    width: grid.side
                    height: grid.side
                    key: modelData.key
                    icon: modelData.icon
                    name: modelData.name
                    font: menu.rowFont
                    onClicked: menu.pick(modelData)
                }
            }
        }
    }

    Component.onCompleted: show([])
}
