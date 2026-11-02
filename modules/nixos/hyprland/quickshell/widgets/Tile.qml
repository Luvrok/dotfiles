import QtQuick
import qs

// a big square of the tools and switches menus: the key that picks it in
// an orange corner, the icon, the name. mode: "" for a tool, "on" fills
// it orange, "off" dims the icon, "busy" pulses. selected is h/l's cursor,
// selectedBorder and selectedWidth say how it stands out. mode, not state:
// Item has a state
Rectangle {
    id: tile

    property string key: ""
    property string icon: ""
    property string name: ""
    property string mode: ""
    property bool selected: false
    property color selectedBorder: Theme.border
    property int selectedWidth: 1
    property font font

    signal clicked

    readonly property bool on: mode === "on"

    color: on ? Theme.selBg : mouse.containsMouse ? Theme.hover : "transparent"
    border.width: selected ? selectedWidth : 1
    border.color: selected ? selectedBorder : mouse.containsMouse || on ? Theme.border : Theme.line
    opacity: 0
    Component.onCompleted: intro.start()

    Behavior on color {
        ColorAnimation {
            duration: 150
        }
    }

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
        color: tile.on ? Theme.sel : Theme.selBg

        Text {
            id: keyText
            anchors.centerIn: parent
            text: tile.key
            color: tile.on ? Theme.selBg : Theme.sel
            font.family: Theme.font
            font.pointSize: 8
            font.bold: true
        }
    }

    Text {
        id: iconText
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -6
        text: tile.icon
        color: tile.on ? Theme.sel : tile.mode === "off" ? Theme.dim : Theme.selBg
        font.family: Theme.font
        font.pointSize: 22

        SequentialAnimation on opacity {
            running: tile.mode === "busy"
            loops: Animation.Infinite
            onRunningChanged: if (!running)
                iconText.opacity = 1
            NumberAnimation {
                to: 0.3
                duration: 500
                easing.type: Easing.InOutSine
            }
            NumberAnimation {
                to: 1
                duration: 500
                easing.type: Easing.InOutSine
            }
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6
        text: tile.name
        color: tile.on ? Theme.sel : Theme.fg
        font: tile.font
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }
}
