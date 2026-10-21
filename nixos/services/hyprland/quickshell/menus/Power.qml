import QtQuick
import Quickshell
import qs

// rofi-powermenu: lock, suspend, logout, reboot, shutdown. every one clears
// the clipboard history first
Menu {
    id: menu

    // icon, command
    readonly property var commands: [
        ["", "loginctl lock-session"],
        ["\u{f0904}", "pkill -x mpv; systemctl suspend"],
        ["\u{f05fd}", "loginctl kill-user \"$USER\""],
        ["", "systemctl reboot"],
        ["⏻", "systemctl poweroff"],
    ]

    readonly property var names: ["lock", "suspend", "logout", "reboot", "shutdown"]

    // tiny icons only, the head names the one under the cursor
    input: false
    title: names[current] ?? ""
    hints: []
    menuWidth: 80
    lines: 5
    padV: 7
    padH: 0
    fontSize: 8
    align: Text.AlignHCenter

    onAccepted: (index, text) => {
        hide();
        // greenclip in i3, cliphist here
        Quickshell.execDetached(["sh", "-c", "rm -f ~/.cache/greenclip.history; cliphist wipe 2>/dev/null; " + commands[index][1]]);
        done();
    }

    Component.onCompleted: show(commands.map(a => a[0]))
}
