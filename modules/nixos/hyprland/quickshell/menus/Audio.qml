import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs
import qs.widgets

// a small pavucontrol: outputs, inputs, the apps that play and the ones
// that record, each with its volume as a bar and the level of what plays
// in it, live. j/k move, h/l -/+5% (with shift 1%), 1-9 sets 10..90%
// (0 is 100%), m mutes, enter makes a device the default (orange) or
// mutes an app. the mouse drags, clicks or scrolls a bar, a left click on a
// device's name makes it the default, a middle or right click mutes.
// s on an app or an input sends it somewhere else too, like a wire in
// qpwgraph: a page of the apps that record and the outputs, the ones it
// goes to orange, enter adds or takes away a wire (scripts/route). youtube
// into discord next to the mic, the mic into the speakers, an app on two
// outputs. the line says where it goes besides the usual
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
    // the send page is for this node
    property var sending: null
    // where it can go: what records, the outputs
    property var targets: []

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

    // the nodes n's sound goes to, level meters left out
    function routes(n) {
        return Pipewire.linkGroups.values.filter(g => g.source === n && kindOf(g.target) !== "").map(g => g.target);
    }

    // where it goes besides the usual: an app's recorders and outputs but
    // the default one, an input's outputs
    function sends(n) {
        if (n.isStream && kindOf(n) !== "app")
            return [];
        return routes(n).filter(t => kindOf(n) === "app" ? t !== Pipewire.defaultAudioSink : kindOf(t) === "out").map(t => label(t));
    }

    // what a recording app gets besides the default input
    function feeds(n) {
        if (kindOf(n) !== "rec")
            return [];
        return Pipewire.linkGroups.values.filter(g => g.target === n && g.source !== Pipewire.defaultAudioSource && kindOf(g.source) !== "").map(g => label(g.source));
    }

    // the wires first, they're short, then what it plays
    function info(n) {
        const to = sends(n), from = feeds(n);
        return [to.length > 0 ? `→ ${to.join(", ")}` : "", from.length > 0 ? `← ${from.join(", ")}` : "", detail(n)].filter(s => s !== "").join("  ");
    }

    function openSend(n) {
        if (!n || (kindOf(n) !== "app" && kindOf(n) !== "in"))
            return;
        sending = n;
        relistTargets();
        lines = Math.max(1, Math.min(targets.length, 10));
        show(targets.map(t => `${label(t)}${kindOf(t) === "rec" && detail(t) !== "" ? ` · ${detail(t)}` : ""}\t${kindOf(t) === "rec" ? "records" : "output"}`));
    }

    function relistTargets() {
        targets = listed.filter(t => t !== sending && (kindOf(t) === "rec" || kindOf(t) === "out"));
    }

    function closeSend() {
        sending = null;
        lines = 0;
        show([]);
    }

    // a wire there or none
    function toggleSend(to) {
        const linked = routes(sending).includes(to);
        Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/route"), linked ? "unlink" : "link", String(sending.id), String(to.id)]);
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

    title: sending ? "send" : "audio"
    icon: sending ? "\u{f1394}" : "\u{f057e}"
    status: sending ? label(sending) : Pipewire.defaultAudioSink ? label(Pipewire.defaultAudioSink) : ""
    statusAccent: sending !== null || Pipewire.defaultAudioSink !== null
    lines: 0
    menuWidth: ch(88)
    hints: sending ? [["j/k", "move"], ["enter", "wire / unwire"], ["h", "back"], ["esc", "close"]] : [["j/k", "move"], ["h/l", "volume"], ["0-9", "level"], ["m", "mute"], ["enter", picked?.isStream ? "mute" : "default"], ...(kindOf(picked ?? {}) === "app" || kindOf(picked ?? {}) === "in" ? [["s", "send"]] : []), ["p", "player"], ["esc", "close"]]
    // the targets it goes to
    active: sending ? targets.map((t, i) => routes(sending).includes(t) ? i : -1).filter(i => i >= 0) : []
    body: sending ? null : mixer

    onAccepted: index => {
        if (sending && targets[index])
            toggleSend(targets[index]);
    }
    onBack: {
        if (sending)
            closeSend();
    }

    keys: e => {
        if (sending)
            return false;
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
        else if (key(e, "s"))
            openSend(n);
        else if (key(e, "p"))
            goTo("player");
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
        // the one it sends from is gone
        if (sending && !listed.includes(sending))
            closeSend();
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

    Component {
        id: mixer
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
                            info: menu.info(node)
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
