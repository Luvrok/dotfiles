import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs

// rofi-bluetooth on one page: the rows are the devices, connected ones
// orange. keys do the rest, on the device under the cursor (enter connects
// or disconnects, p pairs or forgets, t trusts) or on the adapter (o power,
// s scan, a pairable, v discoverable). the menu pulses while an action runs.
// connect and pair go through bluetoothctl, it says if they worked and is
// the agent for pin codes (scripts/bt-pair)
Menu {
    id: menu

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    // the rows' devices
    property var devices: []
    // the device an action runs on, the cursor stays on it
    property BluetoothDevice device: null
    // a pin or passkey page for bt-pair
    property bool asking: false
    // a scan the menu started, esc stops it
    property bool scanning: false

    function notify(text, urgency, timeout) {
        Quickshell.execDetached(["notify-send", "Bluetooth", text, "-h", "string:x-dunst-stack-tag:rofi-bluetooth", "-h", "string:x-canonical-private-synchronous:rofi-bluetooth", "-u", urgency ?? "normal", "-t", String(timeout ?? 3000)]);
    }

    function alias(d) {
        return d.name || d.address;
    }

    // the dim column: connected, paired or the mac, and trusted
    function info(d) {
        const state = d.connected ? "connected" : d.paired ? "paired" : d.address;
        return d.trusted ? `${state}  trusted` : state;
    }

    function refresh() {
        asking = false;
        input = false;
        prompt = "";
        if (!adapter?.enabled) {
            devices = [];
            active = [];
            lines = 0;
            show([]);
            return;
        }
        // the mac is always there, the name may not be yet after a scan
        devices = adapter.devices.values.slice();
        const rows = devices.map(d => {
            const unnamed = !d.name || d.name === d.address || d.name === d.address.replace(/:/g, "-");
            return `${unnamed ? "(без имени)" : d.name}\t${info(d)}`;
        });
        active = devices.map((d, i) => d.connected ? i : -1).filter(i => i >= 0);
        lines = Math.min(rows.length, 10);
        show(rows, Math.max(0, devices.indexOf(device)));
    }

    // the menu pulses while it waits
    function waitFor(cond, then, ms, label) {
        wait(label);
        poll.cond = cond;
        poll.then = then;
        poll.left = (ms ?? 5000) / poll.interval;
        poll.start();
    }

    function powerOn() {
        notify("Включаю Bluetooth...");
        adapter.enabled = true;
        waitFor(() => adapter.enabled, () => {
            notify("Bluetooth включён");
            refresh();
        }, 5000, "powering on");
    }

    function togglePower() {
        if (adapter.enabled) {
            notify("Выключаю Bluetooth...");
            adapter.enabled = false;
            waitFor(() => !adapter.enabled, () => {
                notify("Bluetooth выключен");
                refresh();
            }, 5000, "powering off");
        } else if (adapter.state === BluetoothAdapterState.Blocked) {
            notify("Снимаю блокировку rfkill...");
            Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
            waitFor(() => false, powerOn, 3000, "unblocking");
        } else
            powerOn();
    }

    function toggleScan() {
        if (adapter.discovering) {
            adapter.discovering = false;
            scanning = false;
            waitFor(() => !adapter.discovering, () => {
                notify("Поиск устройств остановлен");
                refresh();
            }, 5000, "stopping");
        } else {
            notify("Поиск устройств... (12 сек)");
            adapter.discovering = true;
            scanning = true;
            waitFor(() => false, () => {
                adapter.discovering = false;
                scanning = false;
                notify("Поиск завершён");
                refresh();
            }, 12000, "scanning");
        }
    }

    // pairable or discoverable
    function toggleAdapter(prop, name) {
        const on = !adapter[prop];
        adapter[prop] = on;
        waitFor(() => adapter[prop] === on, () => {
            notify(`${name}: ${on ? "включено" : "выключено"}`);
            refresh();
        }, 5000, name.toLowerCase());
    }

    function toggleConnection(d) {
        device = d;
        const name = alias(d);
        const connect = !d.connected;
        notify(connect ? `Подключаю ${name}...` : `Отключаю ${name}...`);
        wait(connect ? "connecting" : "disconnecting");
        bluetoothctl.ok = connect ? "Connection successful" : "Successful";
        bluetoothctl.success = connect ? `${name} подключён` : `${name} отключён`;
        bluetoothctl.failure = connect ? `Не удалось подключить ${name}` : `Не удалось отключить ${name}`;
        bluetoothctl.exec(["bluetoothctl", connect ? "connect" : "disconnect", d.address]);
    }

    function togglePaired(d) {
        device = d;
        if (d.paired) {
            d.forget();
            notify("Сопряжение удалено");
            // the device is gone from bluez now
            waitFor(() => false, refresh, 500, "forgetting");
        } else {
            notify("Начинаю сопряжение...");
            wait("pairing");
            pair.exec(["expect", "-f", Quickshell.shellPath("scripts/bt-pair"), d.address]);
        }
    }

    function toggleTrust(d) {
        device = d;
        const trust = !d.trusted;
        d.trusted = trust;
        waitFor(() => d.trusted === trust, () => {
            notify(trust ? "Устройство добавлено в доверенные" : "Доверие снято");
            refresh();
        }, 5000, "trusting");
    }

    // a pin or passkey for bt-pair
    function askCode(kind) {
        asking = true;
        input = true;
        active = [];
        lines = 0;
        prompt = kind === "pin" ? "pin" : "passkey";
        show([]);
    }

    input: false
    title: "bluetooth"
    icon: "\u{f00af}"
    status: !adapter ? "no adapter" : !adapter.enabled ? "off" : [adapter.pairable ? "pairable" : "", adapter.discoverable ? "discoverable" : ""].filter(s => s !== "").join("  ") || "on"
    hint: asking ? "enter send  esc cancel" : adapter?.enabled ? "enter connect  p pair  t trust  s scan  o power  a pairable  v discoverable  esc" : "o power on  esc"
    menuWidth: ch(52)

    keys: e => {
        if (asking || !adapter)
            return false;
        const d = current >= 0 ? devices[current] : null;
        if (key(e, "o"))
            togglePower();
        else if (!adapter.enabled)
            return false;
        else if (key(e, "s"))
            toggleScan();
        else if (key(e, "a"))
            toggleAdapter("pairable", "Pairable");
        else if (key(e, "v"))
            toggleAdapter("discoverable", "Discoverable");
        else if (key(e, "p") && d)
            togglePaired(d);
        else if (key(e, "t") && d)
            toggleTrust(d);
        else
            return false;
        return true;
    }

    // the scan would run on with no one to stop it
    onCancelled: {
        if (scanning)
            adapter.discovering = false;
    }

    onAccepted: (index, text) => {
        if (asking) {
            wait("pairing");
            pair.write(text + "\n");
        } else if (index >= 0)
            toggleConnection(devices[index]);
    }

    Timer {
        id: poll

        property var cond
        property var then
        property int left

        interval: 100
        repeat: true
        onTriggered: {
            if (cond() || --left <= 0) {
                stop();
                then();
            }
        }
    }

    Process {
        id: bluetoothctl

        property string ok
        property string success
        property string failure

        stdout: StdioCollector {
            id: btOut
        }
        onExited: {
            if (btOut.text.includes(ok))
                menu.notify(success);
            else
                menu.notify(failure, "critical");
            menu.refresh();
        }
    }

    Process {
        id: pair
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => menu.askCode(line)
        }
        onExited: menu.refresh()
    }

    Component.onCompleted: refresh()
}
