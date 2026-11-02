import QtQuick
import qs

// the head of a menu: icon and title on the left, the status on the right
// (orange when it's an "on"), a pulsing word next to it while the menu
// works or waits
Item {
    id: head

    property string icon: ""
    property string title: ""
    property string status: ""
    property bool statusAccent: false
    property string pulse: ""
    // centered rows get a centered title, when nothing else is in the head
    property bool centered: false
    property font font

    implicitHeight: titleText.implicitHeight + 6

    Text {
        id: titleText
        x: head.centered && head.status === "" && head.pulse === "" ? (head.width - implicitWidth) / 2 : 12
        text: head.icon !== "" ? `${head.icon}  ${head.title}` : head.title
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
            id: pulseText
            visible: head.pulse !== ""
            text: head.pulse
            color: Theme.dim
            font: head.font

            SequentialAnimation on opacity {
                running: pulseText.visible
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
            width: Math.min(implicitWidth, head.width - titleText.implicitWidth - 48 - (pulseText.visible ? pulseText.implicitWidth + 8 : 0))
            text: head.status
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: head.statusAccent ? Theme.selBg : Theme.dim
            font: head.font
            Behavior on color {
                ColorAnimation {
                    duration: 200
                }
            }
        }
    }
}
