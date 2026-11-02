import QtQuick
import qs

// a line of the audio mixer: the name (orange for the default device),
// dim info after it, a volume bar the mouse can drag, click or scroll, the
// level of what plays inside its fill, the percent. the cursor row is
// tinted and its bar thicker. a muted one is dim and says mute
Item {
    id: fader

    property string name: ""
    property string info: ""
    // 0..1, more is past 100%
    property real value: 0
    // what plays now, 0..1 before the volume
    property real peak: 0
    property bool muted: false
    property bool accent: false
    property bool selected: false
    property font font
    property real nameWidth: 200
    property real barWidth: 160

    // the mouse set a volume, 0..1
    signal moved(real value)
    // a left click on the name
    signal picked
    // a middle or right click
    signal toggled

    implicitHeight: Math.ceil(nameText.implicitHeight) + 8

    Rectangle {
        anchors.fill: parent
        color: fader.selected ? Theme.hover : "transparent"
        Behavior on color {
            ColorAnimation {
                duration: 120
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onClicked: e => {
            if (e.button === Qt.LeftButton)
                fader.picked();
            else
                fader.toggled();
        }
        onWheel: w => fader.moved(Math.max(0, Math.min(1, fader.value + (w.angleDelta.y > 0 ? 0.02 : -0.02))))
    }

    Row {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        width: fader.nameWidth
        spacing: 8
        clip: true

        Text {
            id: nameText
            width: Math.min(implicitWidth, fader.nameWidth)
            text: fader.name
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: fader.muted ? Theme.dim : fader.accent ? Theme.selBg : fader.selected ? Theme.sel : Theme.fg
            font: fader.font
        }
        Text {
            width: Math.max(0, fader.nameWidth - nameText.width - 8)
            visible: width > 0 && text !== ""
            text: fader.info
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.dim
            font: fader.font
        }
    }

    // the bar takes the whole line's height for the mouse
    MouseArea {
        id: barMouse
        x: 12 + fader.nameWidth + 12
        width: fader.barWidth
        height: parent.height
        hoverEnabled: true
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton
        onPressed: e => fader.moved(Math.max(0, Math.min(1, e.x / width)))
        onPositionChanged: e => {
            if (pressed)
                fader.moved(Math.max(0, Math.min(1, e.x / width)));
        }
        onWheel: w => fader.moved(Math.max(0, Math.min(1, fader.value + (w.angleDelta.y > 0 ? 0.02 : -0.02))))

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: fader.selected || barMouse.containsMouse ? 5 : 3
            color: Theme.line
            Behavior on height {
                NumberAnimation {
                    duration: 120
                }
            }

            Rectangle {
                id: fill
                width: Math.round(track.width * Math.max(0, Math.min(1, fader.value)))
                height: parent.height
                color: fader.muted ? Theme.dim : Theme.selBg
                Behavior on width {
                    enabled: !barMouse.pressed
                    NumberAnimation {
                        duration: 150
                        easing.type: Easing.OutCubic
                    }
                }

                // the level, what you hear of it
                Rectangle {
                    visible: !fader.muted
                    width: Math.round(fill.width * Math.max(0, Math.min(1, fader.peak)))
                    height: parent.height
                    color: Theme.sel
                    opacity: 0.75
                    Behavior on width {
                        NumberAnimation {
                            duration: 90
                        }
                    }
                }
            }
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: fader.muted ? "mute" : `${Math.round(fader.value * 100)}%`
        textFormat: Text.PlainText
        color: fader.muted ? Theme.dim : Theme.fg
        font: fader.font
    }
}
