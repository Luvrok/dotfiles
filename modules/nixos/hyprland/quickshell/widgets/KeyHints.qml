import QtQuick
import qs

// the keys at the bottom of a menu: [[key, what], ...], the key bright, what
// it does dim, a dot between them. it wraps, and blinks in when it changes
Flow {
    id: flow

    property var hints: []

    onHintsChanged: blink.restart()

    NumberAnimation {
        id: blink
        target: flow
        property: "opacity"
        from: 0.3
        to: 1
        duration: 220
        easing.type: Easing.OutCubic
    }

    Repeater {
        model: flow.hints

        // the dot goes after a key, so a wrapped line starts with a key
        delegate: Row {
            required property var modelData
            required property int index

            spacing: 3

            Text {
                text: parent.modelData[0]
                color: Theme.fg
                font.family: Theme.font
                font.pointSize: 8
            }
            Text {
                text: parent.modelData[1]
                color: Theme.dim
                font.family: Theme.font
                font.pointSize: 8
            }
            Text {
                visible: parent.index < flow.hints.length - 1
                leftPadding: 2
                rightPadding: 4
                text: "·"
                color: Theme.dim
                font.family: Theme.font
                font.pointSize: 8
            }
        }
    }
}
