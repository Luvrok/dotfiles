import QtQuick
import qs

// the visualizer: bars from Media's levels, growing from the bottom,
// orange. count bars over the width, a thin line when it's quiet
Item {
    id: viz

    property int count: 8
    property real gap: 2
    property color color: Theme.selBg
    readonly property var values: Media.bars(count)

    Repeater {
        model: viz.count

        delegate: Rectangle {
            required property int index
            readonly property real w: (viz.width - (viz.count - 1) * viz.gap) / viz.count
            x: Math.round(index * (w + viz.gap))
            width: Math.max(1, Math.round(w))
            height: Math.max(1, Math.round(viz.height * (viz.values[index] ?? 0)))
            y: viz.height - height
            color: viz.color
            Behavior on height {
                NumberAnimation {
                    duration: 60
                }
            }
        }
    }
}
