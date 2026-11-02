import QtQuick
import qs

// a row of a menu's list: "name\tinfo" puts info in a dim column on the
// right, "" is a divider. selected rows are on the orange cursor, active
// ones orange. new rows come in one after another while the menu says so
Item {
    id: row

    required property int index
    required property int modelData
    // the Menu and its ListView
    required property var menu
    required property var list

    readonly property string raw: menu.rows[modelData] ?? ""
    readonly property int tab: raw.indexOf("\t")
    readonly property bool isDivider: raw === ""
    readonly property bool selected: ListView.isCurrentItem
    readonly property bool accent: menu.active.includes(modelData)
    readonly property int edge: menu.padH + (list.contentHeight > list.height + 1 ? 4 : 0)

    width: list.width
    height: list.rowHeight
    transform: Translate {
        id: shift
    }

    Component.onCompleted: {
        if (!menu.cascading)
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
        x: row.menu.padH
        width: parent.width - 2 * row.menu.padH
        height: 1
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.line
    }

    Text {
        id: info
        visible: !row.isDivider && row.tab >= 0
        anchors.right: parent.right
        anchors.rightMargin: row.edge
        anchors.verticalCenter: parent.verticalCenter
        text: row.tab >= 0 ? row.raw.slice(row.tab + 1) : ""
        textFormat: Text.PlainText
        color: row.selected ? Theme.sel : Theme.dim
        font: row.menu.rowFont
        Behavior on color {
            ColorAnimation {
                duration: 90
            }
        }
    }

    Text {
        visible: !row.isDivider
        anchors.left: parent.left
        anchors.leftMargin: row.menu.padH
        anchors.right: info.visible ? info.left : parent.right
        anchors.rightMargin: info.visible ? 12 : row.edge
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: row.menu.align
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: row.tab >= 0 ? row.raw.slice(0, row.tab) : row.raw
        color: row.selected ? Theme.sel : row.accent ? Theme.selBg : Theme.fg
        font: row.menu.rowFont
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
        onClicked: row.list.currentIndex = row.index
        onDoubleClicked: {
            row.list.currentIndex = row.index;
            row.menu.accept();
        }
    }
}
