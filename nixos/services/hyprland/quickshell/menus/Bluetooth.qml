import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs

// rofi-bluetooth: power, scan, pairable, discoverable and the devices, then a
// page per device to connect, pair and trust. the menu pulses while an
// action runs and comes back after it, like the script. connected devices
// are orange. connect and pair go through bluetoothctl, it says if they
// worked and is the agent for pin codes (scripts/bt-pair)
Menu {
    id: menu

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property string divider: ""
    // main, device or code
    property string page: "main"
    // the main page's devices, by row
    property var devices: []
    property BluetoothDevice device: null
    // a scan the menu started, esc stops it
    property bool scanning: false

    function notify(text, urgency, timeout) {
        Quickshell.execDetached(["notify-send", "Bluetooth", text, "-h", "string:x-dunst-stack-tag:rofi-bluetooth", "-h", "string:x-canonical-private-synchronous:rofi-bluetooth", "-u", urgency ?? "normal", "-t", String(timeout ?? 3000)]);
    }

    function list(rows, accent) {
        input = false;
        active = accent ?? [];
        lines = Math.min(rows.length, 10);
        show(rows);
    }

    function onOff(on) {
        return on ? "on" : "off";
    }

    function yesNo(on) {
        return on ? "yes" : "no";
    }

    function alias(d) {
        return d.name || d.address;
    }

    function mainPage() {
        page = "main";
        device = null;
        if (!adapter?.enabled) {
            list(["power\toff", "exit"]);
            return;
        }
        // the mac is always there, the name may not be yet after a scan
        devices = adapter.devices.values.slice();
        const names = devices.map(d => {
            const unnamed = !d.name || d.name === d.address || d.name === d.address.replace(/:/g, "-");
            return `${unnamed ? "(без имени)" : d.name}\t${d.address}`;
        });
        const connected = devices.map((d, i) => d.connected ? i + 5 : -1).filter(i => i >= 0);
        list(["power\ton", `scan\t${onOff(adapter.discovering)}`, `pairable\t${onOff(adapter.pairable)}`, `discoverable\t${onOff(adapter.discoverable)}`, divider, ...names], connected);
    }

    function devicePage(d) {
        page = "device";
        device = d;
        list([`connected\t${yesNo(d.connected)}`, `paired\t${yesNo(d.paired)}`, `trusted\t${yesNo(d.trusted)}`, divider, "back", "exit"], d.connected ? [0] : []);
    }

    // the menu pulses while it waits
    function waitFor(cond, then, ms, label) {
        wait(label ?? "wait");
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
            mainPage();
        }, 5000, "powering on");
    }

    function togglePower() {
        if (adapter.enabled) {
            notify("Выключаю Bluetooth...");
            adapter.enabled = false;
            waitFor(() => !adapter.enabled, () => {
                notify("Bluetooth выключен");
                mainPage();
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
                mainPage();
            }, 5000, "stopping");
        } else {
            notify("Поиск устройств... (12 сек)");
            adapter.discovering = true;
            scanning = true;
            waitFor(() => false, () => {
                adapter.discovering = false;
                scanning = false;
                notify("Поиск завершён");
                mainPage();
            }, 12000, "scanning");
        }
    }

    function toggleConnection() {
        const d = device;
        const name = alias(d);
        const connect = !d.connected;
        notify(connect ? `Подключаю ${name}...` : `Отключаю ${name}...`);
        wait(connect ? "connecting" : "disconnecting");
        bluetoothctl.ok = connect ? "Connection successful" : "Successful";
        bluetoothctl.success = connect ? `${name} подключён` : `${name} отключён`;
        bluetoothctl.failure = connect ? `Не удалось подключить ${name}` : `Не удалось отключить ${name}`;
        bluetoothctl.exec(["bluetoothctl", connect ? "connect" : "disconnect", d.address]);
    }

    function togglePaired() {
        if (device.paired) {
            device.forget();
            notify("Сопряжение удалено");
            // the device is gone from bluez now
            waitFor(() => false, mainPage, 500, "forgetting");
        } else {
            notify("Начинаю сопряжение...");
            wait("pairing");
            pair.exec(["expect", "-f", Quickshell.shellPath("scripts/bt-pair"), device.address]);
        }
    }

    function toggleTrust() {
        const d = device;
        const trust = !d.trusted;
        d.trusted = trust;
        waitFor(() => d.trusted === trust, () => {
            notify(trust ? "Устройство добавлено в доверенные" : "Доверие снято");
            devicePage(d);
        }, 5000, "trusting");
    }

    // a pin or passkey for bt-pair
    function askCode(kind) {
        page = "code";
        input = true;
        lines = 0;
        active = [];
        prompt = kind === "pin" ? "pin" : "passkey";
        show([]);
    }

    input: false
    title: page === "device" && device ? alias(device) : "bluetooth"
    icon: "\u{f00af}"
    status: page === "device" && device ? device.address : ""
    hint: page === "code" ? "enter send  esc cancel" : "j/k move  enter pick  esc close"
    location: "top-right"
    menuWidth: ch(48)

    // the scan would run on with no one to stop it
    onCancelled: {
        if (scanning)
            adapter.discovering = false;
    }

    onAccepted: (index, text) => {
        if (page === "code") {
            wait("pairing");
            prompt = "";
            pair.write(text + "\n");
            return;
        }
        if (page === "main" && adapter?.enabled) {
            if (index === 0)
                togglePower();
            else if (index === 1)
                toggleScan();
            else if (index === 2) {
                const on = !adapter.pairable;
                adapter.pairable = on;
                waitFor(() => adapter.pairable === on, () => {
                    notify(`Pairable: ${on ? "включено" : "выключено"}`);
                    mainPage();
                });
            } else if (index === 3) {
                const on = !adapter.discoverable;
                adapter.discoverable = on;
                waitFor(() => adapter.discoverable === on, () => {
                    notify(`Discoverable: ${on ? "включено" : "выключено"}`);
                    mainPage();
                });
            } else if (index > 4)
                devicePage(devices[index - 5]);
            else
                cancel();
            return;
        }
        if (page === "main" && index === 0 && adapter) {
            togglePower();
            return;
        }
        if (page === "device") {
            if (index === 0)
                toggleConnection();
            else if (index === 1)
                togglePaired();
            else if (index === 2)
                toggleTrust();
            else if (index === 4)
                mainPage();
            else
                cancel();
            return;
        }
        cancel();
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
            menu.devicePage(menu.device);
        }
    }

    Process {
        id: pair
        stdinEnabled: true
        stdout: SplitParser {
            onRead: line => menu.askCode(line)
        }
        onExited: menu.devicePage(menu.device)
    }

    Component.onCompleted: mainPage()
}
