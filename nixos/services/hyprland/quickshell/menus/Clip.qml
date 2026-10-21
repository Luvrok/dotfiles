import QtQuick
import Quickshell
import Quickshell.Io
import qs

// clipboard history, like sway-clip. hyprland.lua runs
// `wl-paste --watch cliphist store`, that fills it. esc keeps the clipboard
Menu {
    id: menu

    // cliphist lines, "id<tab>preview"
    property var entries: []

    title: "clipboard"
    icon: "\u{f014c}"
    prompt: "search"
    input: true
    enterHint: "copy"
    lines: 15

    onAccepted: (index, text) => {
        hide();
        if (index >= 0)
            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", entries[index]]);
        done();
    }

    Process {
        running: true
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                menu.entries = text.split("\n").filter(l => l !== "");
                // no taller than the history
                menu.lines = Math.max(1, Math.min(menu.entries.length, 15));
                // the preview only, like -display-columns 2. a tab would
                // make a column
                menu.show(menu.entries.map(l => l.slice(l.indexOf("\t") + 1).replace(/\t/g, " ")));
            }
        }
    }
}
