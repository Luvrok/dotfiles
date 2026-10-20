import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi-pass, simpler: pick an entry, then a field (pass, or a "key: value"
// line), it goes to the clipboard and is cleared after 45 s
Menu {
    id: menu

    readonly property string store: Quickshell.env("PASSWORD_STORE_DIR") || Quickshell.env("HOME") + "/.password-store"
    property var entries: []
    // field name -> value of the open entry
    property var fields: ({})
    property string entry: ""

    function copy(value) {
        Quickshell.execDetached(["sh", "-c", `
            printf '%s' "$1" | wl-copy
            notify-send rofi-pass "Copied
Clearing in 45 seconds"
            sleep 45
            wl-copy --clear
            wl-copy --primary --clear`, "sh", value]);
    }

    lines: 15

    onAccepted: (index, text) => {
        if (index < 0) {
            hide();
            done();
        } else if (entry === "") {
            // pinentry needs the keyboard, so out of the way while pass runs
            hide();
            entry = text;
            show_.running = true;
        } else if (index === 0) {
            entry = "";
            show(entries);
        } else {
            hide();
            copy(fields[text]);
            done();
        }
    }

    Process {
        running: true
        command: ["find", "-L", menu.store, "-name", "*.gpg"]
        stdout: StdioCollector {
            onStreamFinished: {
                menu.entries = text.split("\n").filter(l => l !== "").map(l => l.slice(menu.store.length + 1, -4)).sort();
                menu.show(menu.entries);
            }
        }
    }

    Process {
        id: show_
        command: ["pass", "show", menu.entry]
        stdout: StdioCollector {
            id: secret
        }
        // stdout is complete by now
        onExited: code => {
            if (code !== 0) {
                menu.done();
                return;
            }
            const lines = secret.text.split("\n");
            const fields = {};
            for (const line of lines.slice(1)) {
                const sep = line.indexOf(": ");
                if (sep > 0)
                    fields[line.slice(0, sep)] = line.slice(sep + 2);
            }
            fields.pass = lines[0];
            menu.fields = fields;
            menu.show(["< Return", ...Object.keys(fields).sort()]);
        }
    }
}
