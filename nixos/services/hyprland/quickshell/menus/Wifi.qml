import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi-wifi on iwd: scan, then disconnect, rescan or a network, the connected
// one first. a network iwd doesn't know asks for the password
Menu {
    id: menu

    readonly property string dev: "wlan0"
    // the network iwd is on
    property string connected: ""
    // real ssids of the network rows
    property var networks: []
    property bool asking: false
    property string target: ""

    function notify(text) {
        Quickshell.execDetached(["notify-send", "WiFi", text]);
    }

    function scan() {
        notify("Сканирую сети…");
        hide();
        scanner.running = true;
    }

    function parse(out) {
        const clean = out.replace(/\x1B\[[0-9;]*[A-Za-z]/g, "");
        const [show, list] = clean.split("--networks--");
        const conn = show.split("\n").map(l => l.match(/^\s*Connected network\s+(.*\S)\s*$/)).find(m => m);
        connected = conn ? conn[1] : "";

        // "ssid security signal", the ssid may have spaces, iwd may put the
        // signal before the security
        const found = [];
        for (const line of (list ?? "").split("\n")) {
            const t = line.replace(/^[>\s]*/, "").split(/\s+/).filter(s => s !== "");
            let sec = -1;
            for (let i = t.length - 1; i >= 0; i--)
                if (/^(psk|open|8021x)$/i.test(t[i])) {
                    sec = i;
                    break;
                }
            if (sec < 1)
                continue;
            let end = sec;
            let sig = t.slice(sec + 1).join("");
            if (sig === "" && /^\*+$/.test(t[sec - 1])) {
                sig = t[sec - 1];
                end--;
            }
            const ssid = t.slice(0, end).join(" ");
            if (ssid !== "")
                found.push([ssid, (sig.match(/\*/g) ?? []).length]);
        }
        // current first
        found.sort((a, b) => (b[0] === connected) - (a[0] === connected));
        return found;
    }

    function label(ssid, stars) {
        const bars = stars >= 4 ? "▂▄▆█" : stars === 3 ? "▂▄▆_" : stars === 2 ? "▂▄__" : stars === 1 ? "▂___" : "    ";
        const name = ssid.length > 24 ? ssid.slice(0, 21) + "..." : ssid;
        return name.padEnd(24) + "  " + bars;
    }

    function connect(ssid, password) {
        hide();
        connector.ssid = ssid;
        if (password === undefined) {
            notify(`Подключаюсь к ${ssid}…`);
            connector.exec(["sh", "-c", 'iwctl station "$1" disconnect >/dev/null 2>&1; iwctl station "$1" connect "$2" </dev/null 2>/dev/null', "sh", dev, ssid]);
        } else {
            connector.exec(["iwctl", "--passphrase", password, "station", dev, "connect", ssid]);
        }
    }

    input: false
    menuWidth: ch(36)
    fontFamily: "monospace"

    onAccepted: (index, text) => {
        if (asking && text === "") {
            hide();
            notify("Отменено");
            done();
            return;
        }
        if (asking) {
            connect(target, text);
            return;
        }
        const headers = connected !== "" ? 2 : 1;
        if (connected !== "" && index === 0) {
            hide();
            disconnector.running = true;
        } else if (index === headers - 1)
            scan();
        else
            connect(networks[index - headers]);
    }
    onCancelled: {
        if (asking)
            notify("Отменено");
    }

    Process {
        id: scanner
        command: ["sh", "-c", `
            dev=$1
            iwctl station "$dev" scan >/dev/null 2>&1
            for _ in 1 2 3 4 5 6 7 8 9 10; do
                sleep 0.5
                iwctl station "$dev" show | sed 's/\\x1b\\[[0-9;]*[A-Za-z]//g' | grep -Eq '^\\s*Scanning\\s+yes' || break
            done
            iwctl station "$dev" show
            echo --networks--
            iwctl station "$dev" get-networks`, "sh", menu.dev]
        stdout: StdioCollector {
            onStreamFinished: {
                const found = menu.parse(text);
                menu.networks = found.map(n => n[0]);
                const rows = (menu.connected !== "" ? [`disconnect from ${menu.connected}`] : []).concat(["rescan"], found.map(n => menu.label(n[0], n[1])));
                menu.input = false;
                menu.password = false;
                menu.lines = Math.min(rows.length, 10);
                menu.show(rows);
            }
        }
    }

    Process {
        id: disconnector
        command: ["iwctl", "station", menu.dev, "disconnect"]
        onExited: code => {
            menu.notify(code === 0 ? `Отключено: ${menu.connected}` : `Не удалось отключиться от ${menu.connected}`);
            menu.done();
        }
    }

    Process {
        id: connector

        property string ssid

        onExited: code => {
            if (code === 0) {
                menu.notify(`Подключено: ${ssid}`);
                menu.done();
            } else if (!menu.asking) {
                // iwd doesn't know it, ask for the password
                menu.asking = true;
                menu.target = ssid;
                menu.input = true;
                menu.password = true;
                menu.prompt = "Password";
                menu.lines = 0;
                menu.show([]);
            } else {
                menu.notify(`Ошибка подключения к ${ssid}`);
                menu.done();
            }
        }
    }

    Component.onCompleted: scan()
}
