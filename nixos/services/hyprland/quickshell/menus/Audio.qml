import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs

// rofi-audio: pick the default output, the volume on the right, the
// default one in orange
Menu {
    id: menu

    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    readonly property var labels: sinks.map(n => `${n.description || n.nickname || n.name}\t${Math.round(n.audio.volume * 100)}%`)

    input: false
    title: "audio"
    icon: "\u{f057e}"
    enterHint: "use"
    active: [sinks.indexOf(Pipewire.defaultAudioSink)]
    menuWidth: ch(64)

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
