import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.widgets

// btop, smaller, every second (scripts/sysmon): the cpu and its threads,
// load, memory, cache, swap and disks on the left, every gpu with its
// vram, the network and vnstat's day, month and year on the right. p goes
// to the processes
Menu {
    id: menu

    // the last line of scripts/sysmon
    property var stats: null
    // vnstat in bytes: today, yesterday, month, est (the month at this
    // pace), year, all. null without vnstat
    property var traffic: null

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
    status: stats ? `${stats.host} · up ${uptime(stats.uptime)}` : ""
    note: stats ? `${stats.model} · ${stats.cores} cores · ${stats.threads} threads · linux ${stats.kernel}` : ""
    menuWidth: ch(104)
    lines: 0
    hints: [["p", "processes"], ["esc", "close"]]

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
        if (!key(e, "p"))
            return false;
        goTo("processes");
        return true;
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

    Component.onCompleted: show([])
}
