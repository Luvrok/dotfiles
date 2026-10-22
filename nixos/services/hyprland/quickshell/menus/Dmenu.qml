import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi -dmenu for scripts (scripts/dmenu, hypr-dmenu): the rows from a
// file, a search, enter answers with the row's index, esc with nothing.
// markup rows lose their tags, a <span> starts the dim column, like the
// librewolf tab switcher's url
Menu {
    id: menu

    property string file: ""
    property string ask: ""
    property int selected: 0
    property bool markup: false

    signal answered(string index)

    function unmarkup(line) {
        return line.replace(/<span[^>]*>/, "\t").replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&apos;|&#39;/g, "'").replace(/&amp;/g, "&");
    }

    title: ask !== "" ? ask : "pick"
    icon: "\u{f0349}"
    prompt: "search"
    input: true
    menuWidth: ch(100)
    lines: 14

    onAccepted: index => {
        if (index < 0)
            return;
        hide();
        answered(String(index));
        done();
    }
    onCancelled: answered("")

    FileView {
        path: menu.file
        onLoaded: {
            const rows = text().replace(/\n$/, "").split("\n").map(l => menu.markup ? menu.unmarkup(l) : l.replace(/\t/g, " "));
            menu.lines = Math.max(1, Math.min(rows.length, 14));
            menu.show(rows, Math.max(0, Math.min(menu.selected, rows.length - 1)));
        }
        onLoadFailed: menu.answered("")
    }

    Component.onCompleted: show([])
}
