import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi -show drun: the apps from their desktop entries (not every command
// in PATH like rofi-menu, that's thousands on nixos), the ones run before
// on top, most used first. ~/.local/share/hypr-run holds "count<tab>id".
// enter with no match runs the typed text as a command, one that ends
// with ; runs in a terminal. an app that lives on in the background without
// a window and ignores a second start (element) is ended and started again
// (scripts/revive). tab turns on xray: the app or the command runs
// through it (scripts/proxied: --proxy-server for chromium and electron,
// proxychains-ng and the *_proxy vars for the rest)
Menu {
    id: menu

    // [count, desktop id], most used first
    property var cache: []
    // DesktopEntry by row
    property var apps: []
    // tab: what runs goes through xray
    property bool xray: false

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

    // through xray when it's on
    function wrap(command) {
        return xray ? ["bash", Quickshell.shellPath("scripts/proxied"), ...command] : command;
    }

    // an app that lives on without a window (element) gets ended and runs
    // again (scripts/revive)
    function launch(entry) {
        bump(entry.id);
        const command = entry.runInTerminal ? wrap(terminal(entry.command)) : ["bash", Quickshell.shellPath("scripts/revive"), entry.command[0], "--", ...wrap(entry.command)];
        Quickshell.execDetached({
            command: command,
            workingDirectory: entry.workingDirectory
        });
    }

    function runCommand(cmd) {
        if (cmd.trim() === "")
            return;
        Quickshell.execDetached(wrap(cmd.endsWith(";") ? terminal(["sh", "-c", cmd.slice(0, -1)]) : ["sh", "-c", cmd]));
    }

    title: "run"
    icon: "\u{f018d}"
    prompt: "app or command"
    input: true
    enterHint: "run"
    status: xray ? "xray" : ""
    statusAccent: xray
    actions: [["tab", xray ? "direct" : "via xray"]]

    keys: e => {
        if (e.key !== Qt.Key_Tab)
            return false;
        xray = !xray;
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
