import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi-pass, simpler: pick an entry, then a field (pass, or a "key: value"
// line), it goes to the clipboard and is cleared after 45 s. backspace in
// an empty entry goes back to the entries
Menu {
    id: menu

    readonly property string store: Quickshell.env("PASSWORD_STORE_DIR") || Quickshell.env("HOME") + "/.password-store"
    property var entries: []
    // field name -> value of the open entry
    property var fields: ({})
    property var fieldNames: []
    property string entry: ""

    // a page no taller than its rows, the entries are a search, the
    // fields a list
    function page(rows) {
        input = entry === "";
        lines = Math.max(1, Math.min(rows.length, 15));
        show(rows);
    }

    function copy(value) {
        Quickshell.execDetached(["sh", "-c", `
            printf '%s' "$1" | wl-copy
            notify-send rofi-pass "Copied
Clearing in 45 seconds"
            sleep 45
            wl-copy --clear
            wl-copy --primary --clear`, "sh", value]);
    }

    title: entry === "" ? "pass" : entry
    icon: "\u{f0306}"
    prompt: "search"
    input: true
    enterHint: entry === "" ? "open" : "copy"
    actions: entry === "" ? [] : [["⌫", "back"]]
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
        } else {
            hide();
            copy(fields[fieldNames[index]]);
            done();
        }
    }

    onBack: {
        if (entry !== "") {
            entry = "";
            page(entries);
        }
    }

    Process {
        running: true
        command: ["find", "-L", menu.store, "-name", "*.gpg"]
        stdout: StdioCollector {
            onStreamFinished: {
                menu.entries = text.split("\n").filter(l => l !== "").map(l => l.slice(menu.store.length + 1, -4)).sort();
                menu.page(menu.entries);
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
            menu.fieldNames = Object.keys(fields).sort();
            menu.page(menu.fieldNames);
        }
    }
}
