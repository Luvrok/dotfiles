import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi-pass, simpler. enter on an entry opens its fields (pass, or
// "key: value" lines): enter copies one, cleared after 45 s, t types it,
// backspace goes back to the entries. ctrl+a on an entry or its fields
// types the login, tab and the password into the window under the menu,
// like rofi-pass's autotype (an "autotype:" line like "user :tab pass
// :enter" wins)
Menu {
    id: menu

    readonly property string store: Quickshell.env("PASSWORD_STORE_DIR") || Quickshell.env("HOME") + "/.password-store"
    property var entries: []
    // field name -> value of the open entry
    property var fields: ({})
    property var fieldNames: []
    property string entry: ""
    // after pass show: open the "fields", or "type" the login
    property string after: ""

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

    // a field by name, any case
    function field(name) {
        const key = Object.keys(fields).find(k => k.toLowerCase() === name);
        return key !== undefined ? fields[key] : undefined;
    }

    // the autotype line as steps: "=text" or a key like ":tab". user is
    // the login, whatever the entry calls it
    function steps() {
        const login = ["user", "login", "username", "email", "mail"].map(k => field(k)).find(v => v !== undefined);
        const spec = field("autotype") ?? (login !== undefined ? "user :tab pass" : "pass");
        return spec.split(/\s+/).filter(t => t !== "").map(t => t.startsWith(":") ? t : "=" + ((t === "user" ? login : field(t)) ?? ""));
    }

    // wtype into the window that gets focus back, the secrets go over
    // stdin. the menu stays loaded until it's done
    function type(list) {
        hide();
        typer.running = true;
        typer.write(list.join("\n") + "\n");
        typer.stdinEnabled = false;
    }

    // pinentry needs the keyboard, so out of the way while pass runs
    function open(name, next) {
        hide();
        entry = name;
        after = next;
        show_.running = true;
    }

    title: entry === "" ? "pass" : entry
    icon: "\u{f0306}"
    prompt: "search"
    input: true
    enterHint: entry === "" ? "open" : "copy"
    actions: entry === "" ? [["ctrl+a", "type login"]] : [["t", "type"], ["ctrl+a", "type login"], ["⌫", "back"]]
    lines: 15

    keys: e => {
        const pick = current >= 0 ? rows[current] : "";
        if (key(e, "a", Qt.ControlModifier)) {
            if (entry !== "")
                type(steps());
            else if (pick !== "")
                open(pick, "type");
        } else if (entry !== "" && key(e, "t") && current >= 0)
            type(["=" + fields[fieldNames[current]]]);
        else
            return false;
        return true;
    }

    onAccepted: (index, text) => {
        if (index < 0) {
            hide();
            done();
        } else if (entry === "")
            open(text, "fields");
        else {
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
            if (menu.after === "type")
                menu.type(menu.steps());
            else
                menu.page(menu.fieldNames);
        }
    }

    // one step a line, :tab :enter :space :delay or =text
    Process {
        id: typer
        stdinEnabled: true
        command: ["sh", "-c", `
            sleep 0.4
            while IFS= read -r s; do
                case $s in
                    :tab) wtype -k Tab ;;
                    :enter) wtype -k Return ;;
                    :space) wtype -k space ;;
                    :delay) sleep 1 ;;
                    =?*) printf '%s' "\${s#=}" | wtype -d 12 - ;;
                esac
            done`]
        onExited: menu.done()
    }
}
