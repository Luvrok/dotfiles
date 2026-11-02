import QtQuick
import Quickshell
import Quickshell.Io
import qs

// systemd's services and timers, system and user (scripts/units), failed
// first, then the running ones (orange), then the rest, found by name.
// alt+s starts, alt+x stops, alt+r restarts, alt+e enables or disables the
// one under the cursor. enter shows its journal, h or backspace goes back.
// system ones ask for the password in the askpass menu (sudo -A)
Menu {
    id: menu

    // {unit, scope, active, sub, description, enabled} by row
    property var units: []
    // the journal page is for this one
    property var logOf: null
    // what the last action did, in the head for a moment
    property string flash: ""

    function rank(u) {
        return u.active === "failed" ? 0 : u.active === "active" || u.active === "activating" ? 1 : 2;
    }

    function list(text) {
        let all = [];
        try {
            all = JSON.parse(text) ?? [];
        } catch (e) {}
        // a total order, sort() isn't stable here
        all.sort((a, b) => rank(a) - rank(b) || a.unit.localeCompare(b.unit) || a.scope.localeCompare(b.scope));
        const keep = current >= 0 ? units[current] : null;
        units = all;
        active = all.map((u, i) => u.active === "active" ? i : -1).filter(i => i >= 0);
        const rows = all.map(u => `${u.unit}\t${u.active === "active" ? u.sub : u.active}${u.enabled !== "" ? `  ${u.enabled}` : ""}  ${u.scope}`);
        const at = keep ? all.findIndex(u => u.unit === keep.unit && u.scope === keep.scope) : -1;
        lines = Math.max(1, Math.min(rows.length, 16));
        if (rows.length !== 0 && menu.rows.length !== 0)
            update(rows, at >= 0 ? at : undefined);
        else
            show(rows);
    }

    function refresh() {
        lister.running = true;
    }

    function act(verb) {
        // on the journal page the rows are lines, the unit is its own
        const u = logOf ?? (current >= 0 ? units[current] : null);
        if (!u)
            return;
        if (verb === "toggle")
            verb = u.enabled === "enabled" ? "disable" : "enable";
        wait({
            start: "starting",
            stop: "stopping",
            restart: "restarting",
            enable: "enabling",
            disable: "disabling"
        }[verb]);
        doer.what = `${verb} ${u.unit}`;
        doer.exec(["bash", Quickshell.shellPath("scripts/units"), "do", u.scope, verb, u.unit]);
    }

    function openLog(u) {
        logOf = u;
        atTop = false;
        input = false;
        wait("reading");
        reader.exec(["bash", Quickshell.shellPath("scripts/units"), "log", u.scope, u.unit]);
    }

    function closeLog() {
        logOf = null;
        atTop = true;
        input = true;
        lines = 16;
        menuWidth = ch(90);
        units = [];
        show([]);
        refresh();
    }

    title: logOf ? logOf.unit : "systemd"
    icon: "\u{f08d6}"
    status: flash !== "" ? flash : logOf ? `${logOf.active} · ${logOf.scope}` : units.length > 0 ? `${units.filter(u => u.active === "failed").length} failed · ${units.filter(u => u.active === "active").length} running` : ""
    statusAccent: flash !== ""
    prompt: "unit"
    input: true
    enterHint: logOf ? "back" : "journal"
    actions: [["alt+s", "start"], ["alt+x", "stop"], ["alt+r", "restart"], ["alt+e", "enable"]]
    empty: "reading units…"
    menuWidth: ch(90)
    lines: 16

    keys: e => {
        if (key(e, "s", Qt.AltModifier))
            act("start");
        else if (key(e, "x", Qt.AltModifier))
            act("stop");
        else if (key(e, "r", Qt.AltModifier))
            act("restart");
        else if (key(e, "e", Qt.AltModifier))
            act("toggle");
        else
            return false;
        return true;
    }

    onAccepted: index => {
        if (logOf)
            closeLog();
        else if (units[index])
            openLog(units[index]);
    }
    onBack: {
        if (logOf)
            closeLog();
    }

    Timer {
        id: flashEnd
        interval: 3000
        onTriggered: menu.flash = ""
    }

    // the state changes on its own too: a timer fires, a service dies
    Timer {
        interval: 3000
        repeat: true
        running: menu.visible && !menu.logOf
        onTriggered: menu.refresh()
    }

    Process {
        id: lister
        running: true
        command: ["bash", Quickshell.shellPath("scripts/units"), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!menu.logOf && menu.busy === "")
                    menu.list(text);
            }
        }
    }

    Process {
        id: doer
        property string what
        onExited: code => {
            menu.flash = code === 0 ? what : `${what} failed`;
            flashEnd.restart();
            if (menu.logOf)
                menu.openLog(menu.logOf);
            else {
                menu.busy = "";
                menu.refresh();
            }
        }
    }

    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = text.split("\n").filter(l => l !== "").map(l => l.replace(/\t/g, " "));
                menu.active = [];
                menu.lines = 20;
                menu.menuWidth = menu.ch(120);
                menu.show(rows.length > 0 ? rows : ["no journal"], rows.length - 1);
            }
        }
    }

    Component.onCompleted: show([])
}
