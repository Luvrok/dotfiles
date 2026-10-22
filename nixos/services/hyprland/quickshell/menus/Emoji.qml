import QtQuick
import Quickshell
import Quickshell.Io
import qs

// emoji and the symbols a keyboard lacks (— « » → ≈ ...), searched by
// name, the recent ones first. enter copies it, alt+t types it into the
// window under the menu. the emoji and their names come from unicode's
// emoji-test.txt (default.nix links /share/unicode)
Menu {
    id: menu

    readonly property string recentFile: `${Quickshell.env("HOME")}/.local/share/hypr-emoji`
    // the typography the layouts don't have, then arrows and math
    readonly property var symbols: [["—", "em dash"], ["–", "en dash"], ["«", "left guillemet quote"], ["»", "right guillemet quote"], ["„", "low quote"], ["“", "left quote"], ["”", "right quote"], ["…", "ellipsis"], ["·", "middle dot"], ["•", "bullet"], ["№", "numero"], ["§", "section"], ["°", "degree"], ["±", "plus minus"], ["×", "times multiply"], ["÷", "divide"], ["≈", "almost equal"], ["≠", "not equal"], ["≤", "less or equal"], ["≥", "greater or equal"], ["∞", "infinity"], ["√", "square root"], ["→", "arrow right"], ["←", "arrow left"], ["↑", "arrow up"], ["↓", "arrow down"], ["⇒", "double arrow right implies"], ["↔", "arrow left right"], ["€", "euro"], ["₽", "ruble"], ["£", "pound"], ["©", "copyright"], ["®", "registered"], ["™", "trademark"], ["✓", "check mark"], ["✗", "cross mark"], ["⌘", "command"], ["⏎", "return enter"], ["⌫", "backspace"]]
    // [char, name, group] by row
    property var items: []
    property var recent: []

    function build(text) {
        const all = symbols.map(s => [s[0], s[1], "symbol"]);
        let group = "";
        for (const line of text.split("\n")) {
            const g = line.match(/^# group: (.*)$/);
            if (g) {
                group = g[1].toLowerCase();
                continue;
            }
            // 1F600 ; fully-qualified # 😀 E1.0 grinning face
            const m = line.match(/; fully-qualified\s+# (\S+) E[\d.]+ (.*)$/);
            if (m)
                all.push([m[1], m[2], group]);
        }
        // the recent ones first, in their order
        const known = new Map(all.map(i => [i[0], i]));
        const first = recent.filter(c => known.has(c)).map(c => known.get(c));
        items = [...first, ...all.filter(i => !recent.includes(i[0]))];
        show(items.map(i => `${i[0]}  ${i[1]}\t${recent.includes(i[0]) ? "recent" : i[2]}`));
    }

    // 30 at most, the newest first
    function remember(c) {
        const list = [c, ...recent.filter(r => r !== c)].slice(0, 30);
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$1")" && printf "%s\\n" "$2" > "$1"', "sh", recentFile, list.join("\n")]);
    }

    function use(index, type) {
        const it = items[index];
        if (!it)
            return;
        hide();
        remember(it[0]);
        if (type)
            Quickshell.execDetached(["sh", "-c", 'sleep 0.2; printf %s "$1" | wtype -', "sh", it[0]]);
        else
            Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", it[0]]);
        done();
    }

    title: "emoji"
    icon: "\u{f01f5}"
    prompt: "name"
    input: true
    enterHint: "copy"
    actions: [["alt+t", "type"]]
    empty: "reading…"
    menuWidth: ch(64)
    lines: 14

    keys: e => {
        if (!key(e, "t", Qt.AltModifier))
            return false;
        if (current >= 0)
            use(current, true);
        return true;
    }

    onAccepted: index => use(index, false)

    // either can come first, the list is made again when the other comes
    FileView {
        path: menu.recentFile
        printErrors: false
        onLoaded: {
            menu.recent = text().split("\n").filter(l => l !== "");
            if (emojiFile.loaded)
                menu.build(emojiFile.text());
        }
    }

    FileView {
        id: emojiFile
        path: "/run/current-system/sw/share/unicode/emoji/emoji-test.txt"
        onLoaded: menu.build(text())
        onLoadFailed: menu.build("")
    }

    Component.onCompleted: show([])
}
