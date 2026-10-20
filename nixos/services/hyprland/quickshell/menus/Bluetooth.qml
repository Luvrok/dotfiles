import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs

// rofi-bluetooth: power, scan, pairable, discoverable and the devices, then a
// page per device to connect, pair and trust. the menu comes back after
// every action, like the script. connect and pair go through bluetoothctl,
// it says if they worked and is the agent for pin codes (scripts/bt-pair)
Menu {
    id: menu

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property string divider: "---------"
    // main, device or code
    property string page: "main"
    // the main page's devices, by row
    property var devices: []
    property BluetoothDevice device: null

    function notify(text, urgency, timeout) {
        Quickshell.execDetached(["notify-send", "Bluetooth", text, "-h", "string:x-dunst-stack-tag:rofi-bluetooth", "-h", "string:x-canonical-private-synchronous:rofi-bluetooth", "-u", urgency ?? "normal", "-t", String(timeout ?? 3000)]);
    }

    function list(rows) {
        input = false;
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
            list(["Power: off", "Exit"]);
            return;
        }
        // the mac is always there, the name may not be yet after a scan
        devices = adapter.devices.values.slice();
        const names = devices.map(d => {
            const unnamed = !d.name || d.name === d.address || d.name === d.address.replace(/:/g, "-");
            return `${unnamed ? "(без имени)" : d.name}  [${d.address}]`;
        });
        list(["Power: on", `Scan: ${onOff(adapter.discovering)}`, `Pairable: ${onOff(adapter.pairable)}`, `Discoverable: ${onOff(adapter.discoverable)}`, divider, ...names]);
    }

    function devicePage(d) {
        page = "device";
        device = d;
        list([`Connected: ${yesNo(d.connected)}`, `Paired: ${yesNo(d.paired)}`, `Trusted: ${yesNo(d.trusted)}`, divider, "Back", "Exit"]);
    }

    // the menu is hidden while it waits, like rofi while bluetoothctl runs
    function waitFor(cond, then, ms) {
        hide();
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
        });
    }

    function togglePower() {
        if (adapter.enabled) {
            notify("Выключаю Bluetooth...");
            adapter.enabled = false;
            waitFor(() => !adapter.enabled, () => {
                notify("Bluetooth выключен");
                mainPage();
            });
        } else if (adapter.state === BluetoothAdapterState.Blocked) {
            notify("Снимаю блокировку rfkill...");
            Quickshell.execDetached(["rfkill", "unblock", "bluetooth"]);
            waitFor(() => false, powerOn, 3000);
        } else
            powerOn();
    }

    function toggleScan() {
        if (adapter.discovering) {
            adapter.discovering = false;
            waitFor(() => !adapter.discovering, () => {
                notify("Поиск устройств остановлен");
                mainPage();
            });
        } else {
            notify("Поиск устройств... (12 сек)");
            adapter.discovering = true;
            waitFor(() => false, () => {
                adapter.discovering = false;
                notify("Поиск завершён");
                mainPage();
            }, 12000);
        }
    }

    function toggleConnection() {
        const d = device;
        const name = alias(d);
        const connect = !d.connected;
        notify(connect ? `Подключаю ${name}...` : `Отключаю ${name}...`);
        hide();
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
            waitFor(() => false, mainPage, 500);
        } else {
            notify("Начинаю сопряжение...");
            hide();
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
        });
    }

    // a pin or passkey for bt-pair
    function askCode(kind) {
        page = "code";
        input = true;
        lines = 0;
        prompt = kind === "pin" ? "Bluetooth PIN" : "Bluetooth passkey";
        show([]);
    }

    input: false
    location: "top-right"

    onAccepted: (index, text) => {
        if (page === "code") {
            hide();
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
