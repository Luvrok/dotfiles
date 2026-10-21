import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi-killer, by app: every program with a wayland or x11 connection
// (scripts/apps), with its windows or "background" when it has none, like
// an app that lives on after its window closes. enter ends the app and all
// it started: SIGTERM, SIGKILL if it still lives after 2 s. alt+p switches
// to all processes by cpu like rofi-killer, enter kills the group of one.
// quickshell and its group are left alone
Menu {
    id: menu

    // all processes instead of apps
    property bool procs: false
    // {pid, pgid} by row in processes, {pid} in apps
    property var targets: []
    property string appsText: ""
    property string procsText: ""

    // a process's name: the file it runs, without nix's wrapper dots
    function base(args) {
        const file = args.split(" ")[0].split("/").pop();
        return file.replace(/^\.+/, "").replace(/(-wrapped)+$/, "");
    }

    // the desktop entry's name, by window class, id or command. shells
    // and interpreters run too many entries to tell
    function appName(name) {
        if (/^(sh|bash|zsh|env|python[0-9.]*|perl|node|electron[0-9]*)$/.test(name))
            return name;
        const entry = DesktopEntries.heuristicLookup(name) ?? DesktopEntries.applications.values.find(e => e.command.length > 0 && base(e.command[0]) === name);
        return entry?.name || name;
    }

    function size(kb) {
        return kb >= 1048576 ? `${(kb / 1048576).toFixed(1)}G` : `${Math.round(kb / 1024)}M`;
    }

    // the output of scripts/apps list as rows, targets follows
    function apps(text) {
        // the --name-- sections, a ps line starts with its pid
        const parts = {};
        let section = "";
        for (const line of text.split("\n")) {
            const m = line.match(/^--([a-z]+)--$/);
            if (m) {
                section = m[1];
                parts[section] = [];
            } else if (section !== "")
                parts[section].push(line);
        }
        const part = name => (parts[name] ?? []).join("\n");
        const ps = {};
        const kids = {};
        for (const line of part("ps").split("\n")) {
            const m = line.match(/^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\d+)\s+(.*)$/);
            if (!m)
                continue;
            ps[m[1]] = {
                ppid: m[2],
                cpu: parseFloat(m[3]),
                rss: parseInt(m[4]),
                args: m[5]
            };
            if (!kids[m[2]])
                kids[m[2]] = [];
            kids[m[2]].push(m[1]);
        }
        const self = String(Quickshell.processId);
        const gui = new Set(part("gui").split("\n").filter(p => ps[p]));
        gui.add(self);
        // the topmost process with a connection above pid, itself included
        const top = pid => {
            let found = null;
            for (let p = pid; ps[p] && p !== "1"; p = ps[p].ppid)
                if (gui.has(p))
                    found = p;
            return found;
        };
        const found = {};
        const app = pid => {
            if (!found[pid])
                found[pid] = {
                    pid: pid,
                    windows: []
                };
            return found[pid];
        };
        for (const pid of gui)
            app(top(pid));
        let clients = [];
        try {
            clients = JSON.parse(part("clients"));
        } catch (e) {}
        for (const c of clients)
            app(top(String(c.pid)) ?? String(c.pid)).windows.push(c);
        // not quickshell, nor what started it
        delete found[top(self)];

        const list = Object.values(found).filter(a => ps[a.pid]).map(a => {
            // cpu and memory of everything it started
            let cpu = 0, rss = 0;
            const queue = [a.pid];
            while (queue.length > 0) {
                const p = queue.pop();
                cpu += ps[p].cpu;
                rss += ps[p].rss;
                queue.push(...(kids[p] ?? []));
            }
            const n = a.windows.length;
            const name = appName(n > 0 && a.windows[0].class !== "" ? a.windows[0].class : base(ps[a.pid].args));
            const title = n === 1 && a.windows[0].title !== "" && a.windows[0].title !== name ? ` · ${a.windows[0].title}` : "";
            return {
                pid: a.pid,
                name: name,
                row: `${name}${title}\t${n === 0 ? "background" : n === 1 ? "window" : `${n} windows`}  ${cpu.toFixed(1).padStart(5)}%  ${size(rss).padStart(5)}  ${a.pid.padStart(7)}`,
                windowed: n > 0
            };
        });
        // windows first, then the background, by name
        const order = (a, b) => a.name.localeCompare(b.name) || a.pid - b.pid;
        const sorted = [...list.filter(a => a.windowed).sort(order), ...list.filter(a => !a.windowed).sort(order)];
        targets = sorted.map(a => ({
                    pid: a.pid
                }));
        return sorted.map(a => a.row);
    }

    // ps output as rows, targets follows
    function processes(text) {
        const list = text.split("\n").map(l => l.match(/^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)$/)).filter(m => m);
        targets = list.map(m => ({
                    pid: m[1],
                    pgid: m[2]
                }));
        // the command, then user, cpu, memory and pid in a column
        return list.map(m => `${m[6]}\t${m[3]}  ${m[4].padStart(5)}%  ${m[5].padStart(4)}%  ${m[1].padStart(7)}`);
    }

    function page() {
        const text = procs ? procsText : appsText;
        if (text !== "")
            show(procs ? processes(text) : apps(text));
        else
            (procs ? psList : appList).running = true;
    }

    title: "kill"
    icon: "\u{f068c}"
    status: procs ? "all processes" : "apps"
    prompt: procs ? "process" : "app"
    input: true
    enterHint: "kill"
    actions: [["alt+p", procs ? "apps" : "processes"]]
    empty: "looking…"
    menuWidth: ch(100)
    lines: 12

    keys: e => {
        if (!key(e, "p", Qt.AltModifier))
            return false;
        procs = !procs;
        page();
        return true;
    }

    onAccepted: (index, text) => {
        hide();
        const t = targets[index];
        if (index < 0 || !t) {
            done();
            return;
        }
        if (procs)
            Quickshell.execDetached(["sh", "-c", `
                pid=$1 pgid=$2
                case $pgid in "" | 0* | *[!0-9]*) exit 1 ;; esac
                [ "$pgid" = "$(ps -o pgid= -p "$3" | tr -d ' ')" ] && exit 1
                kill -TERM "-$pgid" 2>/dev/null
                sleep 2
                kill -0 "$pid" 2>/dev/null && kill -KILL "-$pgid" 2>/dev/null`, "sh", t.pid, t.pgid, String(Quickshell.processId)]);
        else
            Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/apps"), "kill", t.pid]);
        done();
    }

    Process {
        id: appList
        running: true
        command: ["bash", Quickshell.shellPath("scripts/apps"), "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                menu.appsText = text;
                if (!menu.procs)
                    menu.show(menu.apps(text));
            }
        }
    }

    Process {
        id: psList
        command: ["ps", "-eo", "pid,pgid,user,pcpu,pmem,cmd", "--sort=-pcpu", "--no-headers"]
        stdout: StdioCollector {
            onStreamFinished: {
                menu.procsText = text;
                if (menu.procs)
                    menu.show(menu.processes(text));
            }
        }
    }

    Component.onCompleted: show([])
}
