import QtQuick
import qs

// a line of the system menu: a dim label, a thin bar that fills orange from
// the left (the text line's hairline, a bit thicker), the value, dim info
// on the right. a value below 0 has no bar
Item {
    id: meter

    property string label: ""
    // 0..1
    property real value: -1
    property string text: ""
    property string info: ""
    property font font
    // the same on every line, so the bars line up
    property real labelWidth: 40
    property real barWidth: 160

    implicitHeight: valueText.implicitHeight + 6

    Text {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: meter.label
        color: Theme.dim
        font: meter.font
    }

    Rectangle {
        id: track
        visible: meter.value >= 0
        x: 12 + meter.labelWidth
        anchors.verticalCenter: parent.verticalCenter
        width: meter.barWidth
        height: 3
        color: Theme.line

        Rectangle {
            width: Math.round(track.width * Math.max(0, Math.min(1, meter.value)))
            height: parent.height
            color: Theme.selBg
            Behavior on width {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Text {
        id: valueText
        x: 12 + meter.labelWidth + (track.visible ? meter.barWidth + 12 : 0)
        anchors.verticalCenter: parent.verticalCenter
        text: meter.text
        textFormat: Text.PlainText
        color: Theme.fg
        font: meter.font
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: meter.info
        textFormat: Text.PlainText
        color: Theme.dim
        font: meter.font
    }
}
