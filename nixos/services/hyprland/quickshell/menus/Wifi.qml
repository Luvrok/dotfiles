import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi-wifi on iwd, drawn like the eww wifi menu. the networks come from
// iwd over d-bus (scripts/wifi): the ones it knows right away, then the
// scan fills them in while the keys keep working. strongest first, the
// connected one on top and in orange. enter joins, or leaves the connected
// one, r rescans, d disconnects. a locked network iwd doesn't know asks for
// the password
Menu {
    id: menu

    readonly property string dev: "wlan0"
    // the network iwd is on
    property string connected: ""
    property bool scanned: false
    // {ssid, type, connected, known, signal} by row
    property var networks: []
    property bool asking: false
    property string target: ""

    function notify(text) {
        Quickshell.execDetached(["notify-send", "WiFi", text]);
    }

    function scan() {
        scanner.running = true;
    }

    // ssid, then security and signal in the dim column, like eww but with
    // squares, jetbrains mono has no ▮. signal is dbm * 100
    function label(n) {
        const bars = n.signal >= -6000 ? 4 : n.signal >= -6700 ? 3 : n.signal >= -7500 ? 2 : 1;
        return `${n.ssid}\t${n.type === "8021x" ? "eap" : n.type}  ${"■".repeat(bars)}${"□".repeat(4 - bars)}`;
    }

    // a line from scripts/wifi, the cursor stays on its network
    function list(line) {
        let data;
        try {
            data = JSON.parse(line);
        } catch (e) {
            return;
        }
        // iwd sorts by signal, the connected one goes on top. no sort(),
        // it isn't stable here
        const found = [...data.networks.filter(n => n.connected), ...data.networks.filter(n => !n.connected)];
        const conn = found.find(n => n.connected);
        connected = conn ? conn.ssid : "";
        if (asking || busy !== "")
            return;
        const keep = current >= 0 ? networks[current]?.ssid : undefined;
        networks = found;
        active = conn ? [0] : [];
        lines = Math.max(1, Math.min(found.length, 10));
        const rows = found.map(n => label(n));
        if (!scanned) {
            scanned = true;
            show(rows);
        } else
            update(rows, found.findIndex(n => n.ssid === keep));
    }

    function connect(ssid, password) {
        wait("connecting");
        connector.ssid = ssid;
        if (password === undefined)
            connector.exec(["iwctl", "station", dev, "connect", ssid]);
        else
            connector.exec(["iwctl", "--passphrase", password, "station", dev, "connect", ssid]);
    }

    function disconnect() {
        wait("disconnecting");
        disconnector.running = true;
    }

    function askPassword(ssid) {
        asking = true;
        target = ssid;
        input = true;
        password = true;
        prompt = "password";
        lines = 0;
        show([]);
    }

    input: false
    title: asking ? "enter password" : "wi-fi"
    icon: "\u{f05a9}"
    status: asking ? target : connected !== "" ? connected : scanned ? "offline" : ""
    statusAccent: !asking && connected !== ""
    activity: scanner.running && !asking ? "scanning" : ""
    empty: scanner.running ? "looking for networks…" : "no networks, r to scan"
    searchable: !asking
    enterHint: asking ? "connect" : current >= 0 && networks[current]?.connected ? "leave" : "join"
    actions: [["r", "rescan"], ["d", "disconnect"]]
    menuWidth: ch(48)

    keys: e => {
        if (asking)
            return false;
        if (key(e, "r"))
            scan();
        else if (key(e, "d") && connected !== "")
            disconnect();
        else
            return false;
        return true;
    }

    onAccepted: (index, text) => {
        if (asking) {
            if (text === "") {
                hide();
                notify("Отменено");
                done();
            } else
                connect(target, text);
            return;
        }
        const n = networks[index];
        if (!n)
            return;
        if (n.connected)
            disconnect();
        else if (n.known || n.type === "open")
            connect(n.ssid);
        else
            askPassword(n.ssid);
    }
    onCancelled: {
        if (asking)
            notify("Отменено");
    }

    Process {
        id: scanner
        command: ["bash", Quickshell.shellPath("scripts/wifi"), menu.dev, "scan"]
        stdout: SplitParser {
            onRead: line => menu.list(line)
        }
        onExited: {
            // no iwd or no device
            if (!menu.scanned)
                menu.list('{"networks": []}');
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
            } else if (!menu.asking && menu.networks.find(n => n.ssid === ssid)?.type !== "open") {
                // iwd forgot it or the password changed, ask
                menu.askPassword(ssid);
            } else {
                menu.notify(`Ошибка подключения к ${ssid}`);
                menu.done();
            }
        }
    }

    Component.onCompleted: {
        lines = 1;
        show([]);
        scan();
    }
}
