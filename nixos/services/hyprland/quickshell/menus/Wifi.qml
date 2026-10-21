import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi-wifi on iwd, drawn like the eww wifi menu: it drops from the bar and
// pulses while iwd scans. disconnect, rescan or a network, the connected one
// first and in orange. a network iwd doesn't know asks for the password
Menu {
    id: menu

    readonly property string dev: "wlan0"
    // the network iwd is on
    property string connected: ""
    property bool scanned: false
    // real ssids of the network rows
    property var networks: []
    property bool asking: false
    property string target: ""

    function notify(text) {
        Quickshell.execDetached(["notify-send", "WiFi", text]);
    }

    // the panel stays and pulses, the rows it has stay too
    function scan() {
        if (!visible) {
            lines = 0;
            show([]);
        }
        wait("scanning");
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
                found.push([ssid, (sig.match(/\*/g) ?? []).length, t[sec].toLowerCase()]);
        }
        // current first
        found.sort((a, b) => (b[0] === connected) - (a[0] === connected));
        return found;
    }

    // ssid, then security and signal in the dim column, like eww but with
    // squares, jetbrains mono has no ▮
    function label(ssid, stars, sec) {
        const n = Math.max(0, Math.min(stars, 4));
        return `${ssid}\t${sec === "8021x" ? "eap" : sec}  ${"■".repeat(n)}${"□".repeat(4 - n)}`;
    }

    function connect(ssid, password) {
        wait("connecting");
        connector.ssid = ssid;
        if (password === undefined) {
            connector.exec(["sh", "-c", 'iwctl station "$1" disconnect >/dev/null 2>&1; iwctl station "$1" connect "$2" </dev/null 2>/dev/null', "sh", dev, ssid]);
        } else {
            connector.exec(["iwctl", "--passphrase", password, "station", dev, "connect", ssid]);
        }
    }

    input: false
    title: asking ? "enter password" : "wi-fi"
    icon: "\u{f05a9}"
    status: asking ? target : connected !== "" ? connected : scanned ? "offline" : ""
    hint: asking ? "enter connect  esc cancel" : "j/k move  enter join  r rescan  esc"
    location: "top"
    menuWidth: ch(44)

    keys: e => {
        if (asking || e.key !== Qt.Key_R)
            return false;
        scan();
        return true;
    }

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
            wait("disconnecting");
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
                menu.scanned = true;
                menu.networks = found.map(n => n[0]);
                const head = menu.connected !== "" ? [`disconnect\t${menu.connected}`, "rescan"] : ["rescan"];
                const rows = head.concat(found.map(n => menu.label(n[0], n[1], n[2])));
                menu.input = false;
                menu.password = false;
                const current = menu.networks.indexOf(menu.connected);
                menu.active = current >= 0 ? [head.length + current] : [];
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
                menu.prompt = "password";
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
