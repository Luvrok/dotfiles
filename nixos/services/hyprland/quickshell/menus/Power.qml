import QtQuick
import Quickshell
import qs

// rofi-powermenu: lock, suspend, logout, reboot, shutdown. every one clears
// the clipboard history first
Menu {
    id: menu

    // icon, command
    readonly property var actions: [
        ["", "loginctl lock-session"],
        ["\u{f0904}", "pkill -x mpv; systemctl suspend"],
        ["\u{f05fd}", "loginctl kill-user \"$USER\""],
        ["", "systemctl reboot"],
        ["⏻", "systemctl poweroff"],
    ]

    input: false
    location: "right"
    menuWidth: 85
    lines: 5
    padV: 20
    padH: 0
    align: Text.AlignHCenter

    onAccepted: (index, text) => {
        hide();
        // greenclip in i3, cliphist here
        Quickshell.execDetached(["sh", "-c", "rm -f ~/.cache/greenclip.history; cliphist wipe 2>/dev/null; " + actions[index][1]]);
        done();
    }

    Component.onCompleted: show(actions.map(a => a[0]))
}
