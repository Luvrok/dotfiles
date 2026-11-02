import QtQuick
import Quickshell
import Quickshell.Io
import qs

// every process by the last second's cpu (top -c, kernel threads left
// out), every second, a search like the kill menu. the list sorts itself,
// so it has no cursor until ↑↓: enter ends the one under it, or the first
// match of what's typed (SIGTERM, SIGKILL if it still lives after 2 s).
// alt+s sorts by memory, alt+a goes to the apps (the kill menu)
Menu {
    id: menu

    // {pid, user, cpu, mem, name} by row
    property var procs: []
    property bool byMem: false
    // top's own line: the cpu in use, percent
    property real cpu: 0
    // what enter did, in the head for a moment
    property string flash: ""

    // top's frame being read: its process lines, how many it has, how many
    // came, the frames so far. the first one's cpu isn't the last second
    property var frame: []
    property int frameTotal: 0
    property int frameSeen: 0
    property int frames: 0
    // the process columns by name, from top's header
    property var cols: ({})
    property int colCount: 0

    // kB
    function size(kb) {
        return kb >= 1048576 ? `${(kb / 1048576).toFixed(1)}G` : `${Math.round(kb / 1024)}M`;
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
        // what's typed before the first frame stays
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
        const idle = line.match(/^\s*%Cpu\(s\):.*?([\d.]+) id/);
        if (idle) {
            if (frames >= 2)
                cpu = 100 - parseFloat(idle[1]);
            return;
        }
        // the header: PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ COMMAND,
        // the columns go by these names, the command is last
        if (/^\s*PID\s/.test(line)) {
            const names = line.trim().split(/\s+/);
            const at = {};
            names.forEach((n, i) => at[n] = i);
            cols = at;
            colCount = names.length;
            return;
        }
        const f = line.trim().split(/\s+/);
        if (colCount === 0 || !/^\d+$/.test(f[0]) || f.length < colCount)
            return;
        const col = name => f[cols[name]] ?? "";
        frameSeen++;
        // a kernel thread has no memory of its own
        if (parseFloat(col("VIRT")) > 0)
            frame.push({
                pid: parseInt(col("PID")),
                user: col("USER"),
                mem: kb(col("RES")),
                cpu: parseFloat(col("%CPU")) || 0,
                name: base(f.slice(colCount - 1).join(" "))
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

    title: "processes"
    icon: "\u{f0aa4}"
    status: flash !== "" ? flash : procs.length > 0 ? `${procs.length} procs · cpu ${Math.round(cpu)}%` : ""
    statusAccent: flash !== ""
    prompt: "process"
    input: true
    startOnFirst: false
    enterHint: "end"
    actions: [["alt+s", byMem ? "by cpu" : "by memory"], ["alt+a", "apps"]]
    empty: "reading processes…"
    menuWidth: ch(84)
    lines: 16

    keys: e => {
        if (key(e, "s", Qt.AltModifier)) {
            byMem = !byMem;
            if (frame.length > 0)
                publish();
        } else if (key(e, "a", Qt.AltModifier))
            goTo("kill");
        else
            return false;
        return true;
    }

    // no cursor: the first match of what's typed
    onAccepted: index => {
        if (index >= 0)
            end(procs[index]);
        else if (menu.text !== "" && shown.length > 0)
            end(procs[shown[0]]);
    }

    Timer {
        id: flashEnd
        interval: 3000
        onTriggered: menu.flash = ""
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
