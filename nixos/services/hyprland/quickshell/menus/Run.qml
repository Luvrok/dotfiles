import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi-menu: every command in PATH, the ones run before on top, most used
// first. ~/.local/share/dmenu_cache holds "count<tab>command". a command
// that ends with ; runs in a terminal
Menu {
    id: menu

    property var cache: []

    function run(cmd) {
        const i = cache.findIndex(e => e[1] === cmd);
        if (i >= 0)
            cache[i][0]++;
        else
            cache.unshift([1, cmd]);
        cache.sort((a, b) => b[0] - a[0]);
        cacheFile.setText(cache.map(e => `${e[0]}\t${e[1]}\n`).join(""));

        if (cmd.endsWith(";"))
            Quickshell.execDetached([Quickshell.env("TERMINAL") || "kitty", "-e", cmd.split(";")[0]]);
        else
            Quickshell.execDetached([cmd]);
    }

    lines: 10

    onAccepted: (index, text) => {
        hide();
        // only what's in the list, like rofi-menu
        if (index >= 0)
            run(text);
        done();
    }

    FileView {
        id: cacheFile
        path: Quickshell.env("HOME") + "/.local/share/dmenu_cache"
        blockLoading: true
        printErrors: false
    }

    Process {
        running: true
        // dmenu_path: executables in PATH
        command: ["sh", "-c", "IFS=:; for d in $PATH; do find -L \"$d\" -maxdepth 1 -type f -executable ! -name '.*' -printf '%f\\n'; done 2>/dev/null | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                menu.cache = cacheFile.text().split("\n").filter(l => l.includes("\t")).map(l => {
                    const tab = l.indexOf("\t");
                    return [parseInt(l.slice(0, tab)) || 0, l.slice(tab + 1)];
                });
                const all = text.split("\n").filter(c => /[A-Za-z0-9]/.test(c));
                menu.show([...new Set([...menu.cache.map(e => e[1]), ...all])].filter(c => c !== ""));
            }
        }
    }
}
