pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// what the switches menu turns on and off, and the bar shows while it's
// on: vpn (v2rayN and its xray), zapret, dnscrypt-proxy. a check says if
// it's on, on and off do it. system units go through scripts/units, so
// sudo asks in the askpass menu. a new switch is a line in `list`
Singleton {
    id: root

    readonly property string units: Quickshell.shellPath("scripts/units")
    readonly property var list: [
        {
            key: "v",
            id: "vpn",
            name: "vpn",
            icon: "\u{f0582}",
            check: "pgrep -x xray",
            on: "setsid -f v2rayN >/dev/null 2>&1; sleep 3",
            off: "pkill -x v2rayN; pkill -x xray"
        },
        {
            key: "z",
            id: "zapret",
            name: "zapret",
            icon: "\u{f0499}",
            check: "systemctl is-active -q zapret-discord-youtube",
            on: `bash ${units} do system start zapret-discord-youtube`,
            off: `bash ${units} do system stop zapret-discord-youtube`
        },
        {
            key: "d",
            id: "dns",
            name: "dnscrypt",
            icon: "\u{f048b}",
            check: "systemctl is-active -q dnscrypt-proxy",
            on: `bash ${units} do system start dnscrypt-proxy`,
            off: `bash ${units} do system stop dnscrypt-proxy`
        }
    ]
    // id: true or false, from the last check
    property var states: ({})
    // ids being switched
    property var pending: ({})
    // checks every 2 s while something looks, every 10 s for the bar
    property bool watched: false

    function isOn(id) {
        return states[id] === true;
    }

    function mode(id) {
        return pending[id] ? "busy" : isOn(id) ? "on" : "off";
    }

    function toggle(t) {
        if (pending[t.id])
            return;
        pending = Object.assign({}, pending, {
            [t.id]: true
        });
        const p = switcher.createObject(root, {
            sid: t.id
        });
        p.exec(["sh", "-c", isOn(t.id) ? t.off : t.on]);
    }

    function refresh() {
        // one line per switch, 1 or 0
        checker.exec(["sh", "-c", list.map(t => `{ ${t.check}; } >/dev/null 2>&1 && echo 1 || echo 0`).join("; ")]);
    }

    Component {
        id: switcher
        Process {
            property string sid
            onExited: {
                root.pending = Object.assign({}, root.pending, {
                    [sid]: false
                });
                root.refresh();
                destroy();
            }
        }
    }

    Process {
        id: checker
        stdout: StdioCollector {
            onStreamFinished: {
                const bits = text.trim().split("\n");
                const next = {};
                root.list.forEach((t, i) => next[t.id] = bits[i] === "1");
                root.states = next;
            }
        }
    }

    Timer {
        interval: root.watched ? 2000 : 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
