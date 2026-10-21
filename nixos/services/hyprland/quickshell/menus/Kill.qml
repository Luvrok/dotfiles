import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi-killer: processes by cpu, kill the group of the picked one. SIGTERM,
// SIGKILL if it still lives after 2 s. the kernel and quickshell's own group
// are left alone
Menu {
    id: menu

    // {pid, pgid, user, cpu, mem, cmd} by row
    property var procs: []

    title: "kill"
    icon: "\u{f068c}"
    prompt: "process"
    hint: "enter kill  esc close"
    menuWidth: ch(100)
    lines: 12

    onAccepted: (index, text) => {
        hide();
        if (index >= 0) {
            const pid = procs[index].pid;
            const pgid = procs[index].pgid;
            Quickshell.execDetached(["sh", "-c", `
                pid=$1 pgid=$2
                case $pgid in "" | 0* | *[!0-9]*) exit 1 ;; esac
                [ "$pgid" = "$(ps -o pgid= -p "$3" | tr -d ' ')" ] && exit 1
                kill -TERM "-$pgid" 2>/dev/null
                sleep 2
                kill -0 "$pid" 2>/dev/null && kill -KILL "-$pgid" 2>/dev/null`, "sh", pid, pgid, String(Quickshell.processId)]);
        }
        done();
    }

    Process {
        running: true
        command: ["ps", "-eo", "pid,pgid,user,pcpu,pmem,cmd", "--sort=-pcpu", "--no-headers"]
        stdout: StdioCollector {
            onStreamFinished: {
                menu.procs = text.split("\n").map(l => l.match(/^\s*(\d+)\s+(\d+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.*)$/)).filter(m => m).map(m => ({
                            pid: m[1],
                            pgid: m[2],
                            user: m[3],
                            cpu: m[4],
                            mem: m[5],
                            cmd: m[6]
                        }));
                // the command, then user, cpu, memory and pid in a column
                menu.show(menu.procs.map(p => `${p.cmd}\t${p.user}  ${p.cpu.padStart(5)}%  ${p.mem.padStart(4)}%  ${p.pid.padStart(7)}`));
            }
        }
    }
}
