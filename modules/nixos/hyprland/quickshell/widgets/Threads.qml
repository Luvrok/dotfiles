import QtQuick
import qs

// a small bar for every cpu thread, filling orange from the bottom, under
// the cpu line of the system menu. the bars start where the meters' bars do
Item {
    id: threads

    // percent by thread
    property var use: []
    property real start: 0

    implicitHeight: 22

    Row {
        x: threads.start
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        // a count, not the array: the bars stay and glide every second
        Repeater {
            model: threads.use.length

            delegate: Rectangle {
                required property int index

                width: Math.max(2, Math.min(10, Math.floor((threads.width - threads.start - 12 - (threads.use.length - 1) * 2) / threads.use.length)))
                height: 16
                color: Theme.line

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.round(parent.height * Math.min(100, threads.use[parent.index] ?? 0) / 100)
                    color: Theme.selBg
                    Behavior on height {
                        NumberAnimation {
                            duration: 400
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }
        }
    }
}
