import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.widgets

// a small pavucontrol: outputs, inputs, the apps that play and the ones
// that record, each with its volume as a bar and the level of what plays
// in it, live. j/k move, h/l -/+5% (with shift 1%), 1-9 sets 10..90%
// (0 is 100%), m mutes, enter makes a device the default (orange) or
// mutes an app. the mouse drags, clicks or scrolls a bar, a left click on a
// device's name makes it the default, a middle or right click mutes
Menu {
    id: menu

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    // the ones with a line
    readonly property var listed: nodes.filter(n => kindOf(n) !== "").sort((a, b) => a.id - b.id)
    // the lines change when this does, not on every node that comes and
    // goes: a level meter is a node too
    readonly property string shape: listed.map(n => `${kindOf(n)}:${n.id}`).join(" ")
    // {node, kind} or {head}, in sections
    property var items: []
    // the cursor's node, it stays on it when the list changes
    property var picked: null
    readonly property int at: Math.max(0, items.findIndex(i => i.node && i.node === picked))

    function build() {
        const of = kind => listed.filter(n => kindOf(n) === kind).map(n => ({
                        node: n,
                        kind: kind
                    }));
        const out = [];
        for (const [kind, head] of [["out", "outputs"], ["in", "inputs"], ["app", "apps"], ["rec", "recording"]]) {
            const part = of(kind);
            if (part.length > 0 || kind === "out")
                out.push({
                    head: head
                }, ...part);
        }
        return out;
    }

    function kindOf(n) {
        // a stream once its properties are in, not a level meter (these
        // too, from pavucontrol or the meters here, they're named after
        // the program: .quickshell-wrapped)
        if (n.isStream && (!n.ready || n.properties["stream.monitor"] === "true"))
            return "";
        switch (n.type) {
        case PwNodeType.AudioSink:
        case PwNodeType.AudioDuplex:
            return "out";
        case PwNodeType.AudioSource:
            return "in";
        case PwNodeType.AudioOutStream:
            return "app";
        case PwNodeType.AudioInStream:
            return "rec";
        }
        return "";
    }

    function label(n) {
        if (n.isStream)
            return n.properties["application.name"] || n.description || n.name;
        return n.description || n.nickname || n.name;
    }

    // what an app plays: a tab, a song. not when it's only the app again
    function detail(n) {
        if (!n.isStream)
            return "";
        const media = n.properties["media.name"] ?? "";
        return media !== label(n) ? media : "";
    }

    function isDefault(n) {
        return n === Pipewire.defaultAudioSink || n === Pipewire.defaultAudioSource;
    }

    function go(by) {
        const rows = items.filter(i => i.node);
        if (rows.length === 0)
            return;
        const i = rows.findIndex(r => r.node === picked);
        picked = rows[((i < 0 ? 0 : i + by) % rows.length + rows.length) % rows.length].node;
    }

    function setVolume(n, v) {
        if (n?.audio) {
            n.audio.muted = false;
            n.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    function toggleMute(n) {
        if (n?.audio)
            n.audio.muted = !n.audio.muted;
    }

    function makeDefault(n) {
        if (kindOf(n) === "out")
            Pipewire.preferredDefaultAudioSink = n;
        else if (kindOf(n) === "in")
            Pipewire.preferredDefaultAudioSource = n;
    }

    // enter: the default for a device, mute for an app
    function use(n) {
        if (!n)
            return;
        if (n.isStream)
            toggleMute(n);
        else
            makeDefault(n);
    }

    title: "audio"
    icon: "\u{f057e}"
    status: Pipewire.defaultAudioSink ? label(Pipewire.defaultAudioSink) : ""
    statusAccent: Pipewire.defaultAudioSink !== null
    lines: 0
    menuWidth: ch(88)
    hints: [["j/k", "move"], ["h/l", "volume"], ["0-9", "level"], ["m", "mute"], ["enter", picked?.isStream ? "mute" : "default"], ["esc", "close"]]

    keys: e => {
        const k = e.key;
        const n = picked;
        const step = e.modifiers & Qt.ShiftModifier ? 0.01 : 0.05;
        if (k === Qt.Key_Down || key(e, "j"))
            go(1);
        else if (k === Qt.Key_Up || key(e, "k"))
            go(-1);
        else if (k === Qt.Key_Left || key(e, "h"))
            setVolume(n, (n?.audio?.volume ?? 0) - step);
        else if (k === Qt.Key_Right || key(e, "l"))
            setVolume(n, (n?.audio?.volume ?? 0) + step);
        else if (k >= Qt.Key_0 && k <= Qt.Key_9)
            setVolume(n, k === Qt.Key_0 ? 1 : (k - Qt.Key_0) / 10);
        else if (key(e, "m"))
            toggleMute(n);
        else if (k === Qt.Key_Return || k === Qt.Key_Enter)
            use(n);
        else
            return false;
        return true;
    }

    // the cursor goes to the default output, and there again when its
    // node goes away
    onShapeChanged: relist()

    function relist() {
        items = build();
        if (!picked || !items.some(i => i.node === picked))
            picked = Pipewire.defaultAudioSink ?? items.find(i => i.node)?.node ?? null;
    }

    // what plays, per node. here, not in the lines: they're made again
    // when the list changes and a meter is a stream that comes and goes.
    // none on what records, the meters themselves record
    Variants {
        id: meters
        model: menu.visible ? menu.listed.filter(n => menu.kindOf(n) !== "rec") : []
        PwNodePeakMonitor {
            required property var modelData
            node: modelData
        }
    }

    function peakOf(n) {
        const m = meters.instances.find(m => m.node === n);
        return m ? m.peak : 0;
    }

    // binds the nodes: names, volumes and properties come with it
    PwObjectTracker {
        objects: menu.nodes
    }

    body: Component {
        Column {
            width: parent?.width ?? 0
            topPadding: 2
            bottomPadding: 4

            Text {
                visible: menu.items.length <= 1
                x: 12
                topPadding: 4
                bottomPadding: 4
                text: Pipewire.ready ? "no audio devices" : "waiting for pipewire…"
                color: Theme.dim
                font: menu.rowFont
            }

            Repeater {
                model: menu.items

                delegate: Loader {
                    id: line
                    required property var modelData
                    required property int index
                    width: parent.width
                    sourceComponent: modelData.head ? headLine : faderLine

                    Component {
                        id: headLine
                        Text {
                            x: 12
                            topPadding: line.index > 0 ? 6 : 2
                            bottomPadding: 2
                            text: line.modelData.head
                            color: Theme.dim
                            font.family: Theme.font
                            font.pointSize: 8
                        }
                    }

                    Component {
                        id: faderLine
                        Fader {
                            readonly property var node: line.modelData.node
                            width: line.width
                            name: menu.label(node)
                            info: menu.detail(node)
                            value: node.audio?.volume ?? 0
                            muted: node.audio?.muted ?? false
                            peak: menu.peakOf(node)
                            accent: menu.isDefault(node)
                            selected: line.index === menu.at
                            font: menu.rowFont
                            nameWidth: menu.ch(38)
                            barWidth: width - 24 - nameWidth - 12 - menu.ch(6)
                            onMoved: v => {
                                menu.picked = node;
                                menu.setVolume(node, v);
                            }
                            onPicked: {
                                menu.picked = node;
                                menu.makeDefault(node);
                            }
                            onToggled: menu.toggleMute(node)
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        relist();
        show([]);
    }
}
