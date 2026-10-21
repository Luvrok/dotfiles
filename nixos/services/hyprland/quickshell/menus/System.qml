import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.widgets

// btop, smaller, every second (scripts/sysmon): the cpu and its threads,
// load, memory, cache, swap and disks on the left, every gpu with its
// vram, the network and vnstat's day, month and year on the right. p shows the processes by cpu under
// them (top -c, kernel threads left out), with no cursor until j/k, the
// list sorts itself. / searches, x ends the process under the cursor
// (SIGTERM, SIGKILL if it still lives after 2 s), s sorts by memory or cpu
Menu {
    id: menu

    // the last line of scripts/sysmon
    property var stats: null
    // vnstat in bytes: today, yesterday, month, est (the month at this
    // pace), year, all. null without vnstat
    property var traffic: null
    property bool showProcs: false
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
        return kb >= 1073741824 ? `${(kb / 1073741824).toFixed(1)}T` : kb >= 1048576 ? `${(kb / 1048576).toFixed(1)}G` : `${Math.round(kb / 1024)}M`;
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

    // vnstat's days, months and years, a json line each, for the
    // interface of the default route or the busiest one
    function readTraffic(text) {
        const parts = text.split("\n").map(l => {
            try {
                return JSON.parse(l);
            } catch (e) {
                return null;
            }
        }).filter(p => p !== null);
        if (parts.length < 3) {
            traffic = null;
            return;
        }
        // jsonversion 1 counted KiB
        const unit = parts[0].jsonversion === "1" ? 1024 : 1;
        const pick = o => {
            const ifs = o.interfaces ?? [];
            return ifs.find(i => i.name === stats?.iface) ?? ifs.reduce((a, b) => !a || b.traffic.total.rx + b.traffic.total.tx > a.traffic.total.rx + a.traffic.total.tx ? b : a, null);
        };
        const now = new Date();
        const yday = new Date(now.getFullYear(), now.getMonth(), now.getDate() - 1);
        const at = (list, d, day) => list.find(e => e.date.year === d.getFullYear() && e.date.month === d.getMonth() + 1 && (!day || e.date.day === d.getDate())) ?? {
            rx: 0,
            tx: 0
        };
        const sum = e => ({
                rx: e.rx * unit,
                tx: e.tx * unit
            });
        const days = pick(parts[0])?.traffic.day ?? [];
        const month = sum(at(pick(parts[1])?.traffic.month ?? [], now, false));
        const year = pick(parts[2])?.traffic.year ?? [];
        const start = new Date(now.getFullYear(), now.getMonth(), 1);
        const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);
        traffic = {
            today: sum(at(days, now, true)),
            yesterday: sum(at(days, yday, true)),
            month: month,
            est: (month.rx + month.tx) * (end - start) / Math.max(1, now - start),
            year: sum(year.find(e => e.date.year === now.getFullYear()) ?? {
                rx: 0,
                tx: 0
            }),
            all: sum(pick(parts[0])?.traffic.total ?? {
                rx: 0,
                tx: 0
            })
        };
    }

    // bytes, for vnstat
    function bytes(b) {
        return size(b / 1024);
    }

    // gpu, or igpu for a small one next to a big one, gpu2... for more
    function gpuName(i) {
        const gs = stats?.gpus ?? [];
        if (gs.length < 2)
            return "gpu";
        if (gs[i].vramtotal < 4194304)
            return "igpu";
        const big = gs.filter(g => g.vramtotal >= 4194304).length;
        return big > 1 ? `gpu${gs.slice(0, i + 1).filter(g => g.vramtotal >= 4194304).length}` : "gpu";
    }

    title: "system"
    icon: "\u{f035b}"
    status: flash !== "" ? flash : stats ? `${stats.host} · up ${uptime(stats.uptime)}` : ""
    statusAccent: flash !== ""
    note: stats ? `${stats.model} · ${stats.cores} cores · ${stats.threads} threads · linux ${stats.kernel}` : ""
    searchable: true
    startOnFirst: false
    empty: "reading processes…"
    menuWidth: ch(104)
    lines: showProcs ? 14 : 0
    hints: input ? [["enter", "list"], ["↑↓", "move"], ["q", "back"], ["esc", "close"]] : showProcs ? [["j/k", "move"], ["x", "end"], ["s", byMem ? "by cpu" : "by memory"], ["/", "search"], ["p", "hide"], ["esc", "close"]] : [["p", "processes"], ["/", "search"], ["esc", "close"]]

    body: Component {
        Item {
            id: page

            readonly property var s: menu.stats
            readonly property real half: Math.floor(width / 2)
            readonly property real labelWidth: menu.ch(6.5)
            readonly property real barWidth: menu.ch(14)

            width: parent?.width ?? 0
            implicitHeight: Math.max(left.implicitHeight, right.implicitHeight) + 6

            // cpu, threads, load, memory, swap, disks
            Column {
                id: left
                width: page.half

                Meter {
                    width: parent.width
                    font: menu.rowFont
                    labelWidth: page.labelWidth
                    barWidth: page.barWidth
                    label: "cpu"
                    value: page.s ? page.s.cpu / 1000 : 0
                    text: page.s ? `${Math.round(page.s.cpu / 10)}%` : ""
                    info: !page.s ? "" : [page.s.freq > 0 ? `${(page.s.freq / 1000).toFixed(1)} GHz` : "", page.s.cputemp !== null ? `${Math.round(page.s.cputemp / 1000)}°` : ""].filter(t => t !== "").join(" · ")
                }
                Threads {
                    width: parent.width
                    start: 12 + page.labelWidth
                    use: page.s?.use ?? []
                }
                Meter {
                    width: parent.width
                    font: menu.rowFont
                    labelWidth: page.labelWidth
                    label: "load"
                    text: page.s?.load ?? ""
                    info: page.s ? `${page.s.procs} procs` : ""
                }
                Meter {
                    width: parent.width
                    font: menu.rowFont
                    labelWidth: page.labelWidth
                    barWidth: page.barWidth
                    label: "mem"
                    value: page.s ? page.s.mem / page.s.memtotal : 0
                    text: page.s ? `${menu.size(page.s.mem)} / ${menu.size(page.s.memtotal)}` : ""
                }
                Meter {
                    width: parent.width
                    font: menu.rowFont
                    labelWidth: page.labelWidth
                    barWidth: page.barWidth
                    label: "cache"
                    value: page.s ? page.s.cache / page.s.memtotal : 0
                    text: page.s ? menu.size(page.s.cache) : ""
                }
                Meter {
                    visible: (page.s?.swaptotal ?? 0) > 0
                    width: parent.width
                    font: menu.rowFont
                    labelWidth: page.labelWidth
                    barWidth: page.barWidth
                    label: "swap"
                    value: page.s ? page.s.swap / page.s.swaptotal : 0
                    text: page.s ? `${menu.size(page.s.swap)} / ${menu.size(page.s.swaptotal)}` : ""
                }
                // a count, not the array: the bars stay and glide
                Repeater {
                    model: Math.min(page.s?.disks.length ?? 0, 4)

                    delegate: Meter {
                        required property int index
                        readonly property var disk: page.s.disks[index] ?? ["", 1, 0]

                        width: parent.width
                        font: menu.rowFont
                        labelWidth: page.labelWidth
                        barWidth: page.barWidth
                        label: "disk"
                        value: disk[2] / disk[1]
                        text: `${menu.size(disk[2])} / ${menu.size(disk[1])}`
                        // the mount's last part: outer-1, home, / for the root
                        info: disk[0] === "/" ? "/" : disk[0].split("/").pop()
                    }
                }
            }

            // every gpu, the network, disk io
            Column {
                id: right
                x: page.half
                width: page.width - page.half

                Repeater {
                    model: page.s?.gpus.length ?? 0

                    delegate: Column {
                        id: gpu

                        required property int index
                        readonly property var g: page.s.gpus[index] ?? ({})

                        width: parent.width

                        Meter {
                            width: parent.width
                            font: menu.rowFont
                            labelWidth: page.labelWidth
                            barWidth: page.barWidth
                            label: menu.gpuName(gpu.index)
                            value: (gpu.g.busy ?? 0) / 100
                            text: `${gpu.g.busy ?? 0}%`
                            info: [`${Math.round((gpu.g.power ?? 0) / 1000)} W`, `${Math.round((gpu.g.temp ?? 0) / 1000)}°`, gpu.g.sclk > 0 ? `${(gpu.g.sclk / 1000).toFixed(1)} GHz` : ""].filter(t => t !== "").join(" · ")
                        }
                        Meter {
                            width: parent.width
                            font: menu.rowFont
                            labelWidth: page.labelWidth
                            barWidth: page.barWidth
                            label: "vram"
                            value: gpu.g.vramtotal > 0 ? gpu.g.vram / gpu.g.vramtotal : 0
                            text: `${menu.size(gpu.g.vram ?? 0)} / ${menu.size(gpu.g.vramtotal ?? 0)}`
                            info: `gtt ${menu.size(gpu.g.gtt ?? 0)}`
                        }
                    }
                }
                Meter {
                    width: parent.width
                    font: menu.rowFont
                    labelWidth: page.labelWidth
                    label: "net"
                    text: page.s ? `↓ ${menu.rate(page.s.rates[0])}   ↑ ${menu.rate(page.s.rates[1])}` : ""
                    info: [page.s?.iface ?? "", page.s?.ip ?? ""].filter(t => t !== "").join(" · ")
                }
                // vnstat: what went through today, this month, this year
                Meter {
                    visible: menu.traffic !== null
                    width: parent.width
                    font: menu.rowFont
                    labelWidth: page.labelWidth
                    label: "today"
                    text: menu.traffic ? `↓ ${menu.bytes(menu.traffic.today.rx)}   ↑ ${menu.bytes(menu.traffic.today.tx)}` : ""
                    info: menu.traffic ? `yesterday ${menu.bytes(menu.traffic.yesterday.rx + menu.traffic.yesterday.tx)}` : ""
                }
                Meter {
                    visible: menu.traffic !== null
                    width: parent.width
                    font: menu.rowFont
                    labelWidth: page.labelWidth
                    label: "month"
                    text: menu.traffic ? `↓ ${menu.bytes(menu.traffic.month.rx)}   ↑ ${menu.bytes(menu.traffic.month.tx)}` : ""
                    info: menu.traffic ? `est ${menu.bytes(menu.traffic.est)}` : ""
                }
                Meter {
                    visible: menu.traffic !== null
                    width: parent.width
                    font: menu.rowFont
                    labelWidth: page.labelWidth
                    label: "year"
                    text: menu.traffic ? `↓ ${menu.bytes(menu.traffic.year.rx)}   ↑ ${menu.bytes(menu.traffic.year.tx)}` : ""
                    info: menu.traffic ? `all ${menu.bytes(menu.traffic.all.rx + menu.traffic.all.tx)}` : ""
                }
            }
        }
    }

    keys: e => {
        if (key(e, "p")) {
            showProcs = !showProcs;
            return true;
        }
        // the search needs the list
        if (key(e, "/"))
            showProcs = true;
        if (!showProcs)
            return false;
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

    // vnstatd writes its db every few minutes, a look every 30 s is plenty
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: vnstat.running = true
    }

    Process {
        id: vnstat
        command: ["sh", "-c", "vnstat --json d 2; vnstat --json m 1; vnstat --json y 1"]
        stdout: StdioCollector {
            onStreamFinished: menu.readTraffic(text)
        }
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

    // only while the list is out. a toprc would change the columns, so
    // none: HOME and XDG_CONFIG_HOME point at an empty dir. the C locale
    // for dots in the numbers
    Process {
        running: menu.showProcs
        command: ["top", "-b", "-c", "-d", "1", "-w", "512", "-e", "m"]
        environment: ({
                LC_ALL: "C",
                HOME: "/var/empty",
                XDG_CONFIG_HOME: "/var/empty"
            })
        stdout: SplitParser {
            onRead: line => menu.parse(line)
        }
        onRunningChanged: {
            menu.frames = 0;
            menu.frame = [];
        }
    }

    Component.onCompleted: show([])
}
