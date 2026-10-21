import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

// the notifications that wait (Notifs.list), newest first, live. enter
// runs the default action (or the only one), one with more actions opens
// them as a page. x dismisses one, c all of them, d turns the popups off
// and on (critical ones still pop up)
Menu {
    id: menu

    // the rows' notifications
    property var items: []
    // the actions page is for this one
    property Notification picked: null

    function ago(t) {
        const m = Math.floor((Date.now() - (t ?? Date.now())) / 60000);
        return m < 1 ? "now" : m < 60 ? `${m}m` : m < 1440 ? `${Math.floor(m / 60)}h` : `${Math.floor(m / 1440)}d`;
    }

    function acts(n) {
        return n.actions.filter(a => a.text !== "");
    }

    function build() {
        items = Notifs.list.slice();
        return items.map(n => {
            const head = n.summary !== "" ? n.summary : n.appName;
            const body = Notifs.plain(n.body);
            const app = n.summary !== "" && n.appName !== "" ? `${n.appName}  ` : "";
            return `${body !== "" ? `${head} · ${body}` : head}\t${app}${ago(Notifs.times[n.id])}`;
        });
    }

    // back from the actions page: the cursor on the one it was for
    function list() {
        const was = picked;
        picked = null;
        searchable = true;
        enterHint = "open";
        lines = Math.max(1, Math.min(Notifs.count, 12));
        const rows = build();
        show(rows, Math.max(0, items.indexOf(was)));
    }

    // fresh rows, the cursor stays on its notification
    function relist() {
        if (picked)
            return;
        const keep = current >= 0 ? items[current] : null;
        const rows = build();
        lines = Math.max(1, Math.min(rows.length, 12));
        update(rows, keep ? items.indexOf(keep) : undefined);
    }

    function actionsOf(n) {
        picked = n;
        searchable = false;
        enterHint = "run";
        const a = acts(n);
        lines = Math.min(a.length, 12);
        show(a.map(a => a.text));
    }

    title: "notifications"
    icon: Notifs.quiet ? "\u{f009b}" : "\u{f009a}"
    status: [Notifs.quiet ? "quiet" : "", Notifs.count > 0 ? String(Notifs.count) : ""].filter(s => s !== "").join(" · ")
    statusAccent: Notifs.quiet
    empty: "nothing here"
    actions: picked ? [["h", "back"]] : [["x", "dismiss"], ["c", "clear"], ["d", Notifs.quiet ? "popups on" : "quiet"]]
    menuWidth: ch(84)

    keys: e => {
        if (picked)
            return false;
        const n = current >= 0 ? items[current] : null;
        if (key(e, "x") && n)
            Notifs.dismiss(n);
        else if (key(e, "c"))
            Notifs.clear();
        else if (key(e, "d"))
            Notifs.quiet = !Notifs.quiet;
        else
            return false;
        return true;
    }

    onAccepted: index => {
        if (picked) {
            const a = acts(picked)[index];
            hide();
            a?.invoke();
            done();
            return;
        }
        const n = items[index];
        if (!n)
            return;
        if (acts(n).length > 1) {
            actionsOf(n);
            return;
        }
        hide();
        Notifs.open(n);
        done();
    }

    onBack: {
        if (picked)
            list();
    }

    Connections {
        target: Notifs
        function onListChanged() {
            // the one with the actions page went away
            if (menu.picked && !Notifs.list.includes(menu.picked))
                menu.list();
            else
                menu.relist();
        }
    }

    // the ages
    Timer {
        interval: 30000
        repeat: true
        running: menu.visible
        onTriggered: menu.relist()
    }

    Component.onCompleted: list()
}
