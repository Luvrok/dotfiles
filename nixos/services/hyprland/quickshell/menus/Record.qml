import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

// rofi-recording: sound, quality, fps and what to record, then
// scripts/record starts it. $mod+Shift+r stops it
Menu {
    id: menu

    readonly property var modes: [["Screen + mic + output", "screen_mic_output"], ["Screen only", "screen_only"], ["Screen + mic", "screen_mic"], ["Screen + output", "screen_output"]]
    // the answers so far, a page per question
    property var picks: []
    property var monitors: []

    function ask(rows) {
        lines = rows.length;
        show(rows);
    }

    function start(target, monitor) {
        hide();
        Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/record"), "start", ...picks, target, monitor ?? ""]);
        done();
    }

    input: false
    title: "record"
    icon: "\u{f044a}"
    // the question of this page
    status: ["sound", "quality", "fps", "what", "monitor"][picks.length] ?? ""
    hint: "enter pick  esc"
    menuWidth: 280
    align: Text.AlignHCenter

    onAccepted: (index, text) => {
        switch (picks.length) {
        case 0:
            picks = [modes[index][1]];
            ask(["game", "normal", "lossless"]);
            break;
        case 1:
            picks = [...picks, text];
            ask(["60", "30"]);
            break;
        case 2:
            picks = [...picks, text];
            ask(["fullscreen", "monitor", "window", "area"]);
            break;
        case 3:
            if (text !== "monitor") {
                start(text);
                break;
            }
            picks = [...picks, "monitor"];
            monitors = Hyprland.monitors.values.map(m => m.name);
            ask(monitors);
            break;
        default:
            picks = picks.slice(0, 3);
            start("monitor", text);
        }
    }

    Component.onCompleted: ask(modes.map(m => m[0]))
}
