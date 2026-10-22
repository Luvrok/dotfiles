import QtQuick
import Quickshell
import qs

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
            key: "s",
            name: "shot",
            icon: "\u{f0e51}",
            run: 'g=$(slurp) && grim -g "$g" - | wl-copy --type image/png'
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

                delegate: Rectangle {
                    id: tile
                    required property var modelData
                    required property int index

                    width: grid.side
                    height: grid.side
                    color: mouse.containsMouse ? Theme.hover : "transparent"
                    border.width: 1
                    border.color: mouse.containsMouse ? Theme.border : Theme.line
                    opacity: 0
                    Component.onCompleted: intro.start()

                    NumberAnimation {
                        id: intro
                        target: tile
                        property: "opacity"
                        to: 1
                        duration: 160
                        easing.type: Easing.OutCubic
                    }

                    // the key in the corner
                    Rectangle {
                        x: 5
                        y: 5
                        width: keyText.implicitWidth + 8
                        height: keyText.implicitHeight + 2
                        color: Theme.selBg

                        Text {
                            id: keyText
                            anchors.centerIn: parent
                            text: tile.modelData.key
                            color: Theme.sel
                            font.family: Theme.font
                            font.pointSize: 8
                            font.bold: true
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        anchors.verticalCenterOffset: -6
                        text: tile.modelData.icon
                        color: Theme.selBg
                        font.family: Theme.font
                        font.pointSize: 22
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 6
                        text: tile.modelData.name
                        color: Theme.fg
                        font: menu.rowFont
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: menu.pick(tile.modelData)
                    }
                }
            }
        }
    }

    Component.onCompleted: show([])
}
