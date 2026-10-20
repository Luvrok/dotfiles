import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi-killer: processes by cpu, kill the group of the picked one. SIGTERM,
// SIGKILL if it still lives after 2 s. the kernel and quickshell's own group
// are left alone
Menu {
    id: menu

    menuWidth: 1280
    lines: 10

    onAccepted: (index, text) => {
        hide();
        if (index >= 0) {
            const [pid, pgid] = text.trim().split(/\s+/);
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
            onStreamFinished: menu.show(text.split("\n").filter(l => l !== ""))
        }
    }
}
