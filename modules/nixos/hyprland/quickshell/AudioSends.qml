pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// the sends the audio menu remembers. an app's sound goes to the default
// output anyway; these are the extra wires, the ones that stick. the menu
// adds and drops them, this runs all the time: a stream that lives for a
// moment (a screenshot's click, a soundboard) gets its wires as it comes,
// and a new stream of the app gets them again. one set per app, by
// application.name. a sink is kept by node.name, a recording app by its
// name, so the rules survive a restart and a reopened stream
Singleton {
    id: root

    readonly property string path: `${Quickshell.env("HOME")}/.local/state/quickshell/audio-sends.json`
    // application.name -> [{kind: "sink", node, label} | {kind: "rec", app, label}]
    property var rules: ({})
    // the pairs sent to route, "source:target" -> true: don't send again
    // while the wire is coming
    property var wired: ({})
    // how many times a pair failed. a stream's ports are not there yet for
    // the first try or two, one that keeps failing stops
    property var tries: ({})

    // every audio node, bound for the properties: an app's name, a sink's
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    // changes when a stream appears or its properties come in
    readonly property string shape: nodes.map(n => `${n.id}:${n.ready}:${appOf(n)}:${recApp(n)}:${nodeName(n)}`).join(" ")

    // the app that plays, and only it: not a meter, not a filter chain's
    // own capture stream
    function appOf(n) {
        if (!n?.isStream || !n.ready || n.type !== PwNodeType.AudioOutStream)
            return "";
        if (n.properties["stream.monitor"] === "true")
            return "";
        return n.properties["application.name"] ?? "";
    }

    // the app that records, a send's other end
    function recApp(n) {
        if (!n?.isStream || !n.ready || n.type !== PwNodeType.AudioInStream)
            return "";
        if (n.properties["stream.monitor"] === "true")
            return "";
        return n.properties["application.name"] ?? "";
    }

    function isSink(n) {
        return n?.type === PwNodeType.AudioSink || n?.type === PwNodeType.AudioDuplex;
    }

    // a node, a list of them (one app's streams), or nothing
    function nodesOf(x) {
        if (x == null)
            return [];
        if (Array.isArray(x))
            return x;
        return [x];
    }

    function nodeName(n) {
        return n?.properties?.["node.name"] ?? "";
    }

    // the name the menu shows too
    function labelOf(n) {
        if (n.isStream)
            return n.properties["application.name"] || n.description || n.name;
        return n.description || n.nickname || n.name;
    }

    function ruleFor(t) {
        if (isSink(t))
            return {
                kind: "sink",
                node: nodeName(t),
                label: labelOf(t)
            };
        return {
            kind: "rec",
            app: recApp(t),
            label: labelOf(t)
        };
    }

    function sameRule(a, b) {
        return a.kind === b.kind && (a.kind === "sink" ? a.node === b.node : a.app === b.app);
    }

    function hasRuleKey(app, t) {
        if (app === "" || !t)
            return false;
        const r = ruleFor(t);
        return (rules[app] ?? []).some(x => sameRule(x, r));
    }

    // where an app's sound goes besides the default output, by name. a
    // target that is not here now still counts, it comes back with the rule
    function labelsOfKey(app) {
        if (app === "")
            return [];
        return (rules[app] ?? []).map(r => {
            const t = targetOf(r);
            return t ? labelOf(t) : r.label;
        });
    }

    function labelsOf(n) {
        return labelsOfKey(appOf(n));
    }

    // the node a rule points at, if it is here now
    function targetOf(r) {
        if (r.kind === "sink")
            return nodes.find(n => isSink(n) && nodeName(n) === r.node) ?? null;
        return nodes.find(n => recApp(n) === r.app) ?? null;
    }

    function isLinked(a, b) {
        return Pipewire.linkGroups.values.some(g => g.source === a && g.target === b);
    }

    // on if a wire is there, or the rule is and the wire is coming
    function isOn(n, t, app) {
        const ns = nodesOf(n);
        return ns.some(s => isLinked(s, t)) || hasRuleKey(app ?? (ns.length > 0 ? appOf(ns[0]) : ""), t);
    }

    // link or unlink, from the menu. an app keeps playing on the default
    // output: these are the extra ones. an input has no rules, it just gets
    // a wire where it is sent. n is one node or all of an app's streams,
    // app is its name when they are gone: a send set on a screenshot's
    // click still applies next time
    function toggle(n, t, app) {
        if (!t)
            return false;
        const ns = nodesOf(n);
        const key = app || (ns.length > 0 ? appOf(ns[0]) : "");
        const linked = ns.some(s => isLinked(s, t));
        if (key === "") {
            if (ns.length > 0)
                wire(linked ? "unlink" : "link", ns[0].id, t.id);
            return !linked;
        }
        // the default one can't be taken away, the sound is there already
        if (linked && t === Pipewire.defaultAudioSink)
            return true;
        if (linked || hasRuleKey(key, t)) {
            dropRule(key, t);
            for (const s of ns)
                if (isLinked(s, t))
                    wire("unlink", s.id, t.id);
            return false;
        }
        addRule(key, t);
        return true;
    }

    function addRule(app, t) {
        if (app === "")
            return;
        const r = ruleFor(t);
        if (r.kind === "rec" && r.app === "")
            return;
        const list = (rules[app] ?? []).filter(x => !sameRule(x, r));
        list.push(r);
        save(Object.assign({}, rules, {
            [app]: list
        }));
    }

    function dropRule(app, t) {
        if (app === "" || !rules[app])
            return;
        const r = ruleFor(t);
        const list = (rules[app] ?? []).filter(x => !sameRule(x, r));
        const next = Object.assign({}, rules);
        if (list.length > 0)
            next[app] = list;
        else
            delete next[app];
        save(next);
    }

    function save(next) {
        rules = next;
        Quickshell.execDetached([
            "sh", "-c",
            'mkdir -p "$(dirname "$2")" && printf "%s\\n" "$1" > "$2.$$" && mv "$2.$$" "$2"',
            "sh", JSON.stringify(next), path
        ]);
    }

    // the wires the rules ask for, for the streams that are here now
    function apply() {
        const next = {};
        const nextTries = {};
        for (const s of nodes) {
            const app = appOf(s);
            if (app === "" || !rules[app])
                continue;
            for (const r of rules[app]) {
                const t = targetOf(r);
                if (!t || t === s)
                    continue;
                const k = `${s.id}:${t.id}`;
                if (tries[k])
                    nextTries[k] = tries[k];
                if (isLinked(s, t) || wired[k]) {
                    next[k] = true;
                    continue;
                }
                if ((tries[k] ?? 0) >= 8)
                    continue;
                next[k] = true;
                wire("link", s.id, t.id, k);
            }
        }
        wired = next;
        tries = nextTries;
    }

    // one route at a time
    property var queue: []
    property bool busy: false

    function wire(what, from, to, pair) {
        queue.push([what, from, to, pair]);
        pump();
    }

    function pump() {
        if (busy || queue.length === 0)
            return;
        const w = queue.shift();
        busy = true;
        route.what = w;
        route.command = ["bash", Quickshell.shellPath("scripts/route"), w[0], String(w[1]), String(w[2])];
        route.running = true;
    }

    Process {
        id: route
        property var what: null
        onExited: code => {
            const w = route.what;
            route.what = null;
            if (code !== 0 && w && w[3]) {
                const k = w[3];
                const t = Object.assign({}, root.tries);
                t[k] = (t[k] ?? 0) + 1;
                root.tries = t;
                const wr = Object.assign({}, root.wired);
                delete wr[k];
                root.wired = wr;
                retry.restart();
            }
            root.busy = false;
            root.pump();
        }
    }

    // the ports of a fresh stream take a moment
    Timer {
        id: retry
        interval: 400
        onTriggered: root.apply()
    }

    onShapeChanged: apply()
    onRulesChanged: apply()
    Component.onCompleted: apply()

    PwObjectTracker {
        objects: root.nodes
    }

    FileView {
        path: root.path
        printErrors: false
        onLoaded: {
            try {
                const r = JSON.parse(text());
                if (r && typeof r === "object")
                    root.rules = r;
            } catch (e) {
                root.rules = {};
            }
        }
    }
}
