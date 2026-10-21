import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs

// rofi-audio: pick the default output, rows like `wpctl status`
Menu {
    id: menu

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var labels: sinks.map(n => {
        const mark = n === Pipewire.defaultAudioSink ? "*" : " ";
        const name = n.description || n.nickname || n.name;
        return `${mark}   ${n.id}. ${name} [vol: ${n.audio.volume.toFixed(2)}]`;
    })

    input: false
    menuWidth: ch(80)
    padV: 4
    padH: 0

    onAccepted: (index, text) => {
        hide();
        Pipewire.preferredDefaultAudioSink = sinks[index];
        done();
    }

    // volumes show up once the nodes are bound
    onLabelsChanged: {
        if (visible && labels.length === rows.length)
            rows = labels;
    }

    PwObjectTracker {
        objects: menu.sinks
    }

    Component.onCompleted: {
        if (sinks.length === 0) {
            done();
            return;
        }
        lines = sinks.length;
        show(labels, sinks.indexOf(Pipewire.defaultAudioSink));
    }
}
