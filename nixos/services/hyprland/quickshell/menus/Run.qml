import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi -show drun: the apps from their desktop entries (not every command
// in PATH like rofi-menu, that's thousands on nixos), the ones run before
// on top, most used first. ~/.local/share/hypr-run holds "count<tab>id".
// enter with no match runs the typed text as a command, one that ends
// with ; runs in a terminal. alt+enter runs the app or the command through
// xray: proxychains-ng (/etc/proxychains-xray.conf) and the *_proxy vars
// for what it can't catch (go, static binaries)
Menu {
    id: menu

    // [count, desktop id], most used first
    property var cache: []
    // DesktopEntry by row
    property var apps: []

    function uses(id) {
        return cache.find(e => e[1] === id)?.[0] ?? 0;
    }

    // the rows, apps follows
    function entries() {
        const all = DesktopEntries.applications.values.filter(e => e.name !== "");
        all.sort((a, b) => uses(b.id) - uses(a.id) || a.name.localeCompare(b.name));
        apps = all;
        return all.map(e => e.genericName !== "" && e.genericName !== e.name ? `${e.name}\t${e.genericName}` : e.name);
    }

    function bump(id) {
        const i = cache.findIndex(e => e[1] === id);
        if (i >= 0)
            cache[i][0]++;
        else
            cache.push([1, id]);
        cache.sort((a, b) => b[0] - a[0] || a[1].localeCompare(b[1]));
        cacheFile.setText(cache.map(e => `${e[0]}\t${e[1]}\n`).join(""));
    }

    function terminal(command) {
        return [Quickshell.env("TERMINAL") || "kitty", "-e", ...command];
    }

    // through xray: proxychains and the proxy vars, then the command
    function proxied(command) {
        const p = "http://127.0.0.1:10808";
        return ["env", `http_proxy=${p}`, `https_proxy=${p}`, `HTTP_PROXY=${p}`, `HTTPS_PROXY=${p}`, "all_proxy=socks5://127.0.0.1:10808", "proxychains4", "-q", "-f", "/etc/proxychains-xray.conf", ...command];
    }

    function launch(entry, vpn) {
        bump(entry.id);
        const command = entry.runInTerminal ? terminal(entry.command) : entry.command;
        Quickshell.execDetached({
            command: vpn ? proxied(command) : command,
            workingDirectory: entry.workingDirectory
        });
    }

    function runCommand(cmd, vpn) {
        if (cmd.trim() === "")
            return;
        const command = cmd.endsWith(";") ? terminal(["sh", "-c", cmd.slice(0, -1)]) : ["sh", "-c", cmd];
        Quickshell.execDetached(vpn ? proxied(command) : command);
    }

    title: "run"
    icon: "\u{f018d}"
    prompt: "app or command"
    input: true
    enterHint: "run"
    actions: [["alt+enter", "via xray"]]

    keys: e => {
        if (!((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && e.modifiers & Qt.AltModifier))
            return false;
        hide();
        if (current >= 0)
            launch(apps[current], true);
        else
            runCommand(menu.text, true);
        done();
        return true;
    }
    empty: "looking for apps…"
    lines: 10

    onAccepted: (index, text) => {
        hide();
        if (index >= 0)
            launch(apps[index]);
        else
            runCommand(text);
        done();
    }

    FileView {
        id: cacheFile
        path: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/hypr-run"
        blockLoading: true
        printErrors: false
    }

    // the entries are read in the background, the first time it can be
    // after the menu opens. what's typed stays
    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            menu.update(menu.entries());
        }
    }

    Component.onCompleted: {
        cache = cacheFile.text().split("\n").filter(l => l.includes("\t")).map(l => {
            const tab = l.indexOf("\t");
            return [parseInt(l.slice(0, tab)) || 0, l.slice(tab + 1)];
        });
        show(entries());
    }
}
