import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs

// every window of every tag, searched by class and title, the tag it's on
// in the dim column. the focused one is orange, the cursor starts on the
// one focused before it, like alt-tab. enter focuses (hyprland goes to its
// tag and monitor), alt+x closes it
Menu {
    id: menu

    // the windows by row
    property var wins: []

    function cls(t) {
        return t.lastIpcObject?.class ?? t.wayland?.appId ?? "";
    }

    function build() {
        // most recently focused first: hyprland counts focus in focusHistoryID
        const list = Hyprland.toplevels.values.filter(t => t.workspace).slice();
        const hist = t => t.lastIpcObject?.focusHistoryID ?? 999;
        list.sort((a, b) => hist(a) - hist(b) || a.address.localeCompare(b.address));
        wins = list;
        const focused = Hyprland.activeToplevel;
        active = list.map((t, i) => t === focused ? i : -1).filter(i => i >= 0);
        lines = Math.max(1, Math.min(list.length, 14));
        show(list.map(t => `${cls(t) !== "" ? cls(t) + "  " : ""}${t.title}\t${Hypr.tagName(t.workspace)}`), list.length > 1 ? 1 : 0);
    }

    function addr(t) {
        return `0x${t.address.replace(/^0x/, "")}`;
    }

    title: "windows"
    icon: "\u{f05b2}"
    status: `${wins.length}`
    prompt: "window"
    input: true
    enterHint: "focus"
    actions: [["alt+x", "close"]]
    empty: "no windows"
    menuWidth: ch(90)

    keys: e => {
        if (!key(e, "x", Qt.AltModifier) || current < 0)
            return false;
        Hyprland.dispatch(`hl.dsp.window.close({ window = "address:${addr(wins[current])}" })`);
        refresh.restart();
        return true;
    }

    onAccepted: index => {
        const t = wins[index];
        hide();
        if (t)
            Hyprland.dispatch(`hl.dsp.focus({ window = "address:${addr(t)}" })`);
        done();
    }

    // the list after a close, once hyprland has let the window go
    Timer {
        id: refresh
        interval: 150
        onTriggered: {
            Hyprland.refreshToplevels();
            menu.build();
        }
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        build();
    }
}
