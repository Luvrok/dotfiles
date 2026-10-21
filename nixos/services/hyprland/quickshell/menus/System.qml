import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.widgets

// btop, smaller: cpu, memory, the gpu and the network on top
// (scripts/sysmon), the processes by cpu under them (top -c, kernel
// threads left out), all of it every second. / searches, x ends the process under
// the cursor (SIGTERM, SIGKILL if it still lives after 2 s), s sorts by
// memory or cpu
Menu {
    id: menu

    // the last line of scripts/sysmon
    property var stats: null
    // {pid, user, cpu, mem, name} by row
    property var procs: []
    property bool byMem: false
    // what x did, in the head for a moment
    property string flash: ""

    // top's frame being read: its process lines, how many it has, how many
    // came, the frames so far. the first one's cpu isn't the last second
    property var frame: []
    property int frameTotal: 0
    property int frameSeen: 0
    property int frames: 0

    // kB
    function size(kb) {
        return kb >= 1048576 ? `${(kb / 1048576).toFixed(1)}G` : `${Math.round(kb / 1024)}M`;
    }

    // bytes a second
    function rate(b) {
        return b >= 1048576 ? `${(b / 1048576).toFixed(1)}M/s` : b >= 1024 ? `${Math.round(b / 1024)}K/s` : `${b}B/s`;
    }

    function uptime(s) {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    // a process's name: the file it runs, without nix's wrapper dots. top
    // -c gives the command line, the kernel cuts names at 15 characters
    function base(cmd) {
        return cmd.split(" ")[0].split("/").pop().replace(/^\.+/, "").replace(/(-wrapped)+$/, "");
    }

    // top's RES with -e m: 278.0m, or 1.2g when it doesn't fit
    function kb(res) {
        const n = parseFloat(res);
        const unit = res.slice(-1);
        return Math.round(n * (unit === "g" ? 1048576 : unit === "t" ? 1073741824 : unit === "k" ? 1 : 1024));
    }

    // the frame as rows, the cursor stays on its process
    function publish() {
        const keep = current >= 0 ? procs[current]?.pid : undefined;
        // a total order, sort() isn't stable here
        const list = frame.slice().sort((a, b) => (byMem ? b.mem - a.mem : b.cpu - a.cpu) || a.pid - b.pid);
        procs = list;
        const rows = list.map(p => `${p.name}\t${p.user}  ${p.cpu.toFixed(1).padStart(5)}%  ${size(p.mem).padStart(5)}  ${String(p.pid).padStart(7)}`);
        if (frames === 2 && menu.rows.length === 0)
            show(rows);
        else
            update(rows, list.findIndex(p => p.pid === keep));
    }

    // a blank line comes glued to the next one: "\ntop - ..."
    function parse(line) {
        if (/^\s*top - /.test(line)) {
            frame = [];
            frameSeen = 0;
            frames++;
            return;
        }
        const tasks = line.match(/^\s*Tasks:\s+(\d+)/);
        if (tasks) {
            frameTotal = parseInt(tasks[1]);
            return;
        }
        // PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ COMMAND
        const m = line.match(/^\s*(\d+)\s+(\S+)\s+\S+\s+\S+\s+(\S+)\s+(\S+)\s+\S+\s+\S\s+([\d.]+)\s+[\d.]+\s+\S+\s+(.*)$/);
        if (!m)
            return;
        frameSeen++;
        // a kernel thread has no memory of its own
        if (parseFloat(m[3]) > 0)
            frame.push({
                pid: parseInt(m[1]),
                user: m[2],
                mem: kb(m[4]),
                cpu: parseFloat(m[5]),
                name: base(m[6])
            });
        if (frameSeen === frameTotal && frames >= 2)
            publish();
    }

    function end(p) {
        if (!p || p.pid === Quickshell.processId)
            return;
        Quickshell.execDetached(["sh", "-c", 'kill -TERM "$1" 2>/dev/null; sleep 2; kill -0 "$1" 2>/dev/null && kill -KILL "$1"', "sh", String(p.pid)]);
        flash = `ended ${p.name}`;
        flashEnd.restart();
    }

    title: "system"
    icon: "\u{f035b}"
    status: flash !== "" ? flash : stats ? `up ${uptime(stats.uptime)} · load ${stats.load}` : ""
    statusAccent: flash !== ""
    searchable: true
    empty: "reading processes…"
    menuWidth: ch(76)
    lines: 14
    hints: input ? [["enter", "list"], ["↑↓", "move"], ["q", "back"], ["esc", "close"]] : [["j/k", "move"], ["x", "end"], ["s", byMem ? "by cpu" : "by memory"], ["/", "search"], ["esc", "close"]]

    body: Component {
        Column {
            readonly property real labelWidth: menu.ch(5)
            readonly property real barWidth: menu.ch(26)
            readonly property var s: menu.stats
            readonly property var gpu: s?.gpu ?? null

            width: parent?.width ?? 0
            bottomPadding: 6

            Meter {
                width: parent.width
                font: menu.rowFont
                labelWidth: parent.labelWidth
                barWidth: parent.barWidth
                label: "cpu"
                value: parent.s ? parent.s.cpu / 1000 : 0
                text: parent.s ? `${Math.round(parent.s.cpu / 10)}%` : ""
                info: parent.s?.cputemp ? `${Math.round(parent.s.cputemp / 1000)}°` : ""
            }
            Meter {
                width: parent.width
                font: menu.rowFont
                labelWidth: parent.labelWidth
                barWidth: parent.barWidth
                label: "mem"
                value: parent.s ? parent.s.mem / parent.s.memtotal : 0
                text: parent.s ? `${menu.size(parent.s.mem)} / ${menu.size(parent.s.memtotal)}` : ""
                info: parent.s?.swaptotal > 0 ? `swap ${menu.size(parent.s.swap)}` : ""
            }
            Meter {
                visible: parent.gpu !== null
                width: parent.width
                font: menu.rowFont
                labelWidth: parent.labelWidth
                barWidth: parent.barWidth
                label: "gpu"
                value: parent.gpu ? parent.gpu.busy / 100 : 0
                text: parent.gpu ? `${parent.gpu.busy}%` : ""
                info: parent.gpu ? `${Math.round(parent.gpu.power / 1000)} W · ${Math.round(parent.gpu.temp / 1000)}°` : ""
            }
            Meter {
                visible: parent.gpu !== null
                width: parent.width
                font: menu.rowFont
                labelWidth: parent.labelWidth
                barWidth: parent.barWidth
                label: "vram"
                value: parent.gpu ? parent.gpu.vram / parent.gpu.vramtotal : 0
                text: parent.gpu ? `${menu.size(parent.gpu.vram)} / ${menu.size(parent.gpu.vramtotal)}` : ""
            }
            Meter {
                width: parent.width
                font: menu.rowFont
                labelWidth: parent.labelWidth
                label: "net"
                text: parent.s ? `↓ ${menu.rate(parent.s.rx)}   ↑ ${menu.rate(parent.s.tx)}` : ""
            }
        }
    }

    keys: e => {
        if (key(e, "x"))
            end(procs[current]);
        else if (key(e, "s")) {
            byMem = !byMem;
            if (frame.length > 0)
                publish();
        } else
            return false;
        return true;
    }

    // enter in the search goes back to the list, the filter stays
    onAccepted: {
        if (input)
            closeSearch(true);
    }

    Timer {
        id: flashEnd
        interval: 3000
        onTriggered: menu.flash = ""
    }

    Process {
        running: true
        command: ["bash", Quickshell.shellPath("scripts/sysmon")]
        stdout: SplitParser {
            onRead: line => {
                try {
                    menu.stats = JSON.parse(line);
                } catch (e) {}
            }
        }
    }

    // a toprc would change the columns, so none: HOME and XDG_CONFIG_HOME
    // point at an empty dir. the C locale for dots in the numbers
    Process {
        running: true
        command: ["top", "-b", "-c", "-d", "1", "-w", "512", "-e", "m"]
        environment: ({
                LC_ALL: "C",
                HOME: "/var/empty",
                XDG_CONFIG_HOME: "/var/empty"
            })
        stdout: SplitParser {
            onRead: line => menu.parse(line)
        }
    }

    Component.onCompleted: show([])
}
