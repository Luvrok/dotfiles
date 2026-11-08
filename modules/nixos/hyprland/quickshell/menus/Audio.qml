import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import qs
import qs.widgets

// a small pavucontrol: outputs, inputs, the apps that play and the ones
// that record, each with its volume as a bar and the level of what plays
// in it, live. a playing app is one line: its tabs, windows and sounds
// together, the bar and the mute over all of them. j/k move, h/l -/+5%
// (with shift 1%), 1-9 sets 10..90% (0 is 100%), m mutes, enter makes a
// device the default (orange) or mutes an app. the mouse drags, clicks or
// scrolls a bar, a left click on a device's name makes it the default, a
// middle or right click mutes.
// s on an app or an input sends it somewhere else too, like a wire in
// qpwgraph: a page of the apps that record and the outputs, the ones it
// goes to orange, enter adds or takes away a wire (scripts/route). youtube
// into discord next to the mic, the mic into the speakers, an app on two
// outputs. an app keeps playing on the default output, the wires are what
// comes on top of it. for an app the wires are remembered (AudioSends):
// the streams that live for a moment, a screenshot's click or a
// soundboard, get them too, and so does a new stream of the app. the
// default output is not a row there, it stays; the line says where it
// goes besides the usual
Menu {
    id: menu

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    // the rows: a device or a recording stream, or all of an app's
    // streams together
    readonly property var listed: makeRows()
    // the lines change when this does, not on every node that comes and
    // goes: a level meter is a node too. an app's row changes when one of
    // its streams comes or goes
    readonly property string shape: listed.map(r => `${rowKey(r)}(${nodesOf(r).map(n => n.id).join(",")})`).join(" ")
    // {row} or {head}, in sections
    property var items: []
    // the cursor's row, it stays on it when the list changes
    property var picked: null
    readonly property int at: Math.max(0, items.findIndex(i => i.row && rowKey(i.row) === rowKey(picked)))
    // the send page is for this row
    property var sending: null
    // the page stays up when the streams are gone (a screenshot's click):
    // the app's name is what a rule is kept by, and the row only says what
    // is wired right now
    property bool sendingPage: false
    property string sendApp: ""
    property string sendLabel: ""
    property bool sendInput: false
    // where it can go: what records, the outputs
    property var targets: []

    // one row per device, one per recording stream, one per app: its
    // playback streams by application.name, the tabs of a browser
    function makeRows() {
        const rows = [];
        for (const n of nodes) {
            const kind = kindOf(n);
            if (kind === "out" || kind === "in" || kind === "rec")
                rows.push({
                    kind: kind,
                    node: n
                });
        }
        const apps = new Map();
        for (const n of nodes) {
            if (kindOf(n) !== "app")
                continue;
            const name = n.properties["application.name"] ?? "";
            const key = name !== "" ? `a:${name}` : `n:${n.id}`;
            if (!apps.has(key))
                apps.set(key, {
                    kind: "app",
                    app: name,
                    key: key,
                    nodes: []
                });
            apps.get(key).nodes.push(n);
        }
        for (const row of apps.values()) {
            row.nodes.sort((a, b) => a.id - b.id);
            rows.push(row);
        }
        return rows.sort((a, b) => firstId(a) - firstId(b));
    }

    function isApp(x) {
        return x?.kind === "app" && x.nodes !== undefined;
    }

    // a bare node, a row, or all of an app's streams
    function nodesOf(x) {
        if (!x)
            return [];
        if (x.nodes)
            return x.nodes;
        if (x.node)
            return [x.node];
        return [x];
    }

    function nodeOf(x) {
        return nodesOf(x)[0] ?? null;
    }

    function firstId(x) {
        return nodesOf(x)[0]?.id ?? 0;
    }

    function rowKey(x) {
        if (!x)
            return "";
        if (x.key)
            return x.key;
        if (x.node)
            return `n:${x.node.id}`;
        if (x.id !== undefined)
            return `n:${x.id}`;
        return "";
    }

    function build() {
        const of = kind => listed.filter(r => r.kind === kind).map(r => ({
                        row: r,
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

    function kindOf(x) {
        if (isApp(x))
            return "app";
        if (x?.kind && x.node)
            return x.kind;
        const n = x;
        if (!n)
            return "";
        // a stream once its properties are in, not a level meter (these
        // too, from pavucontrol or the meters here, they're named after
        // the program: .quickshell-wrapped)
        if (n.isStream && (!n.ready || n.properties["stream.monitor"] === "true"))
            return "";
        // a filter chain's own stream: deepfilter records into it, but it
        // is not a program and there is nobody to send it to
        if (n.isStream && n.properties["node.virtual"] === "true" && !n.properties["application.name"])
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

    function label(x) {
        if (isApp(x))
            return x.app || label(nodeOf(x));
        const n = nodeOf(x);
        if (!n)
            return "";
        if (n.isStream)
            return n.properties["application.name"] || n.description || n.name;
        return n.description || n.nickname || n.name;
    }

    // what an app plays: a tab, a song. not when it's only the app again.
    // an app's line has all of them
    function detail(x) {
        if (isApp(x)) {
            const out = [];
            for (const n of x.nodes) {
                const d = detail(n);
                if (d !== "" && !out.includes(d))
                    out.push(d);
            }
            return out.join(" · ");
        }
        const n = nodeOf(x);
        if (!n || !n.isStream)
            return "";
        const media = n.properties["media.name"] ?? "";
        return media !== label(n) ? media : "";
    }

    // the nodes a row's sound goes to, level meters left out
    function routes(x) {
        const ns = nodesOf(x);
        return Pipewire.linkGroups.values.filter(g => ns.includes(g.source) && kindOf(g.target) !== "").map(g => g.target).filter((t, i, all) => all.indexOf(t) === i);
    }

    // where it goes besides the usual: an app's recorders and outputs but
    // the default one, an input's outputs. an app's sends are remembered,
    // the ones not wired yet (the stream is fresh, its target is away)
    // still count
    function sends(x) {
        const kind = kindOf(x);
        const n = nodeOf(x);
        if (n?.isStream && kind !== "app")
            return [];
        const live = routes(x).filter(t => kind === "app" ? t !== Pipewire.defaultAudioSink : kindOf(t) === "out").map(t => label(t));
        if (kind !== "app")
            return live;
        const app = isApp(x) ? x.app : AudioSends.appOf(n);
        return [...new Set([...live, ...AudioSends.labelsOfKey(app)])];
    }

    // what a recording app gets besides the default input
    function feeds(x) {
        if (kindOf(x) !== "rec")
            return [];
        const n = nodeOf(x);
        return Pipewire.linkGroups.values.filter(g => g.target === n && g.source !== Pipewire.defaultAudioSource && kindOf(g.source) !== "").map(g => label(g.source));
    }

    // the wires first, they're short, then what it plays
    function info(x) {
        const to = sends(x), from = feeds(x);
        return [to.length > 0 ? `→ ${to.join(", ")}` : "", from.length > 0 ? `← ${from.join(", ")}` : "", detail(x)].filter(s => s !== "").join("  ");
    }

    function openSend(x) {
        const kind = kindOf(x);
        if (!x || (kind !== "app" && kind !== "in"))
            return;
        sending = x;
        sendingPage = true;
        sendApp = kind === "app" ? (x.app ?? "") : "";
        sendLabel = label(x);
        sendInput = kind === "in";
        relistTargets();
        lines = Math.max(1, Math.min(targets.length, 10));
        show(targets.map(t => `${label(t)}${kindOf(t) === "rec" && detail(t) !== "" ? ` · ${detail(t)}` : ""}\t${kindOf(t) === "rec" ? "records" : "output"}`));
    }

    function relistTargets() {
        // an app always plays on the default output, so it is not a row
        // there: enter on it would take the usual one away
        const usual = sendApp !== "";
        targets = listed.filter(t => (t.kind === "rec" || t.kind === "out") && !(usual && t.node === Pipewire.defaultAudioSink));
    }

    function closeSend() {
        sending = null;
        sendingPage = false;
        sendApp = "";
        sendLabel = "";
        sendInput = false;
        lines = 0;
        show([]);
    }

    // a wire there or none, remembered for an app
    function toggleSend(to) {
        AudioSends.toggle(sending ? nodesOf(sending) : [], to.node, sendApp);
    }

    function isDefault(x) {
        const kind = kindOf(x), n = nodeOf(x);
        return (kind === "out" && n === Pipewire.defaultAudioSink) || (kind === "in" && n === Pipewire.defaultAudioSource);
    }

    function go(by) {
        const rows = items.filter(i => i.row);
        if (rows.length === 0)
            return;
        const i = rows.findIndex(r => rowKey(r.row) === rowKey(picked));
        picked = rows[((i < 0 ? 0 : i + by) % rows.length + rows.length) % rows.length].row;
    }

    // one bar for all of an app's streams
    function value(x) {
        const ns = nodesOf(x).filter(n => n.audio);
        if (ns.length === 0)
            return 0;
        return ns.reduce((sum, n) => sum + n.audio.volume, 0) / ns.length;
    }

    function muted(x) {
        const ns = nodesOf(x).filter(n => n.audio);
        return ns.length > 0 && ns.every(n => n.audio.muted);
    }

    function setVolume(x, v) {
        const value = Math.max(0, Math.min(1, v));
        for (const n of nodesOf(x)) {
            if (n.audio) {
                n.audio.muted = false;
                n.audio.volume = value;
            }
        }
    }

    function toggleMute(x) {
        const ns = nodesOf(x).filter(n => n.audio);
        if (ns.length === 0)
            return;
        const mute = !ns.every(n => n.audio.muted);
        for (const n of ns)
            n.audio.muted = mute;
    }

    function makeDefault(x) {
        const kind = kindOf(x), n = nodeOf(x);
        if (kind === "out" && n)
            Pipewire.preferredDefaultAudioSink = n;
        else if (kind === "in" && n)
            Pipewire.preferredDefaultAudioSource = n;
    }

    // enter: the default for a device, mute for an app
    function use(x) {
        const kind = kindOf(x);
        if (kind === "app" || kind === "rec")
            toggleMute(x);
        else
            makeDefault(x);
    }

    title: sendingPage ? "send" : "audio"
    icon: sendingPage ? "\u{f1394}" : "\u{f057e}"
    status: sendingPage ? sendLabel : Pipewire.defaultAudioSink ? label(Pipewire.defaultAudioSink) : ""
    statusAccent: sendingPage || Pipewire.defaultAudioSink !== null
    // the default is the one with the orange name, the mic apps record
    // from and the output that is always there
    note: sendingPage ? (sendInput ? "also goes here; apps record from the default input (orange)" : "also plays here; the default output stays, the wire sticks") : ""
    lines: 0
    menuWidth: ch(88)
    hints: sendingPage ? [["j/k", "move"], ["enter", "wire / unwire"], ["h", "back"], ["esc", "close"]] : [["j/k", "move"], ["h/l", "volume"], ["0-9", "level"], ["m", "mute"], ["enter", kindOf(picked ?? {}) === "app" || kindOf(picked ?? {}) === "rec" ? "mute" : "default"], ...(kindOf(picked ?? {}) === "app" || kindOf(picked ?? {}) === "in" ? [["s", "send"]] : []), ["p", "player"], ["esc", "close"]]
    // the targets it goes to, a remembered one too
    active: sendingPage ? targets.map((t, i) => AudioSends.isOn(sending ? nodesOf(sending) : [], t.node, sendApp) ? i : -1).filter(i => i >= 0) : []
    body: sendingPage ? null : mixer

    onAccepted: index => {
        if (sendingPage && targets[index])
            toggleSend(targets[index]);
    }
    onBack: {
        if (sendingPage)
            closeSend();
    }

    keys: e => {
        if (sendingPage)
            return false;
        const k = e.key;
        const n = picked;
        const step = e.modifiers & Qt.ShiftModifier ? 0.01 : 0.05;
        if (k === Qt.Key_Down || key(e, "j"))
            go(1);
        else if (k === Qt.Key_Up || key(e, "k"))
            go(-1);
        else if (k === Qt.Key_Left || key(e, "h"))
            setVolume(n, value(n) - step);
        else if (k === Qt.Key_Right || key(e, "l"))
            setVolume(n, value(n) + step);
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
        // the one it sends from is gone. an app's page stays: its sound
        // that made the stream is gone too, but the rule is named after
        // the app and applies to its next stream. a new stream of the app
        // takes the page's row again
        if (sendingPage) {
            const key = sendApp !== "" ? `a:${sendApp}` : (sending ? rowKey(sending) : "");
            const found = key !== "" ? listed.find(r => rowKey(r) === key) : null;
            if (found)
                sending = found;
            else if (sendApp === "")
                closeSend();
            else
                sending = null;
        }
        // the row is made again when one of its streams comes or goes:
        // keep the cursor on the fresh one, not on the old list
        const keep = picked ? listed.find(r => rowKey(r) === rowKey(picked)) : null;
        picked = keep ?? listed.find(r => r.node === Pipewire.defaultAudioSink) ?? listed[0] ?? null;
    }

    // what plays, per node. here, not in the lines: they're made again
    // when the list changes and a meter is a stream that comes and goes.
    // none on what records, the meters themselves record. an app's row
    // shows the loudest of its streams.
    // the list is kept as it is when the nodes are the same: a meter is a
    // stream too, and a model made again on each node would make one more
    // meter for it, and so on. a node without a kind (a meter before its
    // properties are in) gets none
    property var meterNodes: []
    readonly property string meterShape: nodes.map(n => `${n.id}:${n.ready}:${kindOf(n)}`).join(" ")

    function retrackMeters() {
        const want = menu.visible ? nodes.filter(n => {
            const kind = kindOf(n);
            return kind === "out" || kind === "in" || kind === "app";
        }) : [];
        if (want.length === meterNodes.length && want.every((n, i) => n === meterNodes[i]))
            return;
        meterNodes = want;
    }

    onMeterShapeChanged: retrackMeters()
    onVisibleChanged: retrackMeters()

    Variants {
        id: meters
        model: meterNodes
        PwNodePeakMonitor {
            required property var modelData
            node: modelData
        }
    }

    function peakOf(x) {
        let peak = 0;
        for (const n of nodesOf(x)) {
            const m = meters.instances.find(m => m.node === n);
            if (m)
                peak = Math.max(peak, m.peak);
        }
        return peak;
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
                            readonly property var row: line.modelData.row
                            width: line.width
                            name: menu.label(row)
                            info: menu.info(row)
                            value: menu.value(row)
                            muted: menu.muted(row)
                            peak: menu.peakOf(row)
                            accent: menu.isDefault(row)
                            selected: line.index === menu.at
                            font: menu.rowFont
                            nameWidth: menu.ch(38)
                            barWidth: width - 24 - nameWidth - 12 - menu.ch(6)
                            onMoved: v => {
                                menu.picked = row;
                                menu.setVolume(row, v);
                            }
                            onPicked: {
                                menu.picked = row;
                                menu.makeDefault(row);
                            }
                            onToggled: menu.toggleMute(row)
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        relist();
        retrackMeters();
        show([]);
    }
}
