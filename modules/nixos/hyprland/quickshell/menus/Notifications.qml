import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs

// the notifications that wait (Notifs.list), newest first, live, an app
// with more than one folded into a line of its own: enter opens its page.
// enter on a notification runs the default action (or the only one), one
// with more actions opens them as a page, r answers one that takes a reply
// (telegram) in the text line. x dismisses one or a whole app, c all of
// them, d turns the popups off and on (critical ones still pop up). h or
// backspace goes back a page
Menu {
    id: menu

    // the rows: {n} a notification or {app, list} an app's
    property var items: []
    // "list", "app" (its notifications), "actions" or "reply" (for picked)
    property string page: "list"
    property string app: ""
    property Notification picked: null

    function ago(t) {
        const m = Math.floor((Date.now() - (t ?? Date.now())) / 60000);
        return m < 1 ? "now" : m < 60 ? `${m}m` : m < 1440 ? `${Math.floor(m / 60)}h` : `${Math.floor(m / 1440)}d`;
    }

    function acts(n) {
        return n.actions.filter(a => a.text !== "");
    }

    function appOf(n) {
        return n.appName || n.desktopEntry || "?";
    }

    function line(n, withApp) {
        const head = n.summary !== "" ? n.summary : n.appName;
        const body = Notifs.plain(n.body);
        const app = withApp && n.summary !== "" && n.appName !== "" ? `${n.appName}  ` : "";
        const reply = n.hasInlineReply ? "↩ " : "";
        return `${reply}${body !== "" ? `${head} · ${body}` : head}\t${app}${ago(Notifs.times[n.id])}`;
    }

    // the rows of the page, items follows
    function build() {
        if (page === "app") {
            const list = Notifs.list.filter(n => appOf(n) === app);
            items = list.map(n => ({
                        n: n
                    }));
            return list.map(n => line(n, false));
        }
        // an app with more than one gets one line, where its newest is
        const groups = {};
        for (const n of Notifs.list)
            (groups[appOf(n)] = groups[appOf(n)] ?? []).push(n);
        const seen = new Set();
        const out = [];
        for (const n of Notifs.list) {
            const a = appOf(n);
            if (seen.has(a))
                continue;
            if (groups[a].length > 1) {
                seen.add(a);
                out.push({
                    app: a,
                    list: groups[a]
                });
            } else
                out.push({
                    n: n
                });
        }
        items = out;
        return out.map(i => i.n ? line(i.n, true) : `${i.app}  ${i.list.length} · ${Notifs.plain(i.list[0].summary)}\t${ago(Notifs.times[i.list[0].id])}`);
    }

    function go(to, keep) {
        page = to;
        if (to === "list")
            app = "";
        picked = to === "actions" || to === "reply" ? picked : null;
        atTop = to === "list";
        input = to === "reply";
        searchable = to === "list" || to === "app";
        enterHint = to === "reply" ? "send" : to === "actions" ? "run" : "open";
        prompt = to === "reply" ? (picked?.inlineReplyPlaceholder || "reply") : "";
        if (to === "actions") {
            const a = acts(picked);
            lines = Math.min(a.length, 12);
            show(a.map(a => a.text));
        } else if (to === "reply") {
            lines = 0;
            show([]);
        } else {
            const rows = build();
            lines = Math.max(1, Math.min(rows.length, 12));
            show(rows, Math.max(0, items.findIndex(i => keep && (i.n === keep || i.app === keep))));
        }
    }

    // fresh rows, the cursor stays on its notification or app
    function relist() {
        if (page !== "list" && page !== "app")
            return;
        if (page === "app" && !Notifs.list.some(n => appOf(n) === app)) {
            go("list");
            return;
        }
        const was = current >= 0 ? items[current] : null;
        const rows = build();
        lines = Math.max(1, Math.min(rows.length, 12));
        update(rows, was ? items.findIndex(i => (was.n && i.n === was.n) || (was.app && i.app === was.app)) : undefined);
    }

    title: page === "app" ? app : page === "reply" ? "reply" : "notifications"
    icon: page === "reply" ? "\u{f045a}" : Notifs.quiet ? "\u{f009b}" : "\u{f009a}"
    status: page === "reply" ? (picked?.summary ?? "") : [Notifs.quiet ? "quiet" : "", Notifs.count > 0 ? String(Notifs.count) : ""].filter(s => s !== "").join(" · ")
    statusAccent: Notifs.quiet
    empty: "nothing here"
    actions: page === "actions" ? [["h", "back"]] : page === "reply" ? [] : [["x", "dismiss"], ["r", "reply"], ["c", "clear"], ["d", Notifs.quiet ? "popups on" : "quiet"], ...(page === "app" ? [["h", "back"]] : [])]
    menuWidth: ch(84)

    keys: e => {
        if (page !== "list" && page !== "app")
            return false;
        const it = current >= 0 ? items[current] : null;
        if (key(e, "x") && it) {
            for (const n of it.n ? [it.n] : it.list)
                Notifs.dismiss(n);
        } else if (key(e, "r") && it?.n?.hasInlineReply) {
            picked = it.n;
            go("reply");
        } else if (key(e, "c"))
            Notifs.clear();
        else if (key(e, "d"))
            Notifs.quiet = !Notifs.quiet;
        else
            return false;
        return true;
    }

    onAccepted: (index, text) => {
        if (page === "reply") {
            if (text !== "" && picked)
                picked.sendInlineReply(text);
            hide();
            done();
            return;
        }
        if (page === "actions") {
            const a = acts(picked)[index];
            hide();
            a?.invoke();
            done();
            return;
        }
        const it = items[index];
        if (!it)
            return;
        if (it.app) {
            app = it.app;
            go("app");
            return;
        }
        if (acts(it.n).length > 1) {
            picked = it.n;
            go("actions");
            return;
        }
        hide();
        Notifs.open(it.n);
        done();
    }

    onBack: {
        if (page === "app")
            go("list", app);
        else if (page === "actions" || page === "reply")
            go(app !== "" && Notifs.list.some(n => appOf(n) === app) ? "app" : "list", picked);
    }

    Connections {
        target: Notifs
        function onListChanged() {
            // the one with the actions or the reply went away
            if (menu.picked && !Notifs.list.includes(menu.picked) && (menu.page === "actions" || menu.page === "reply"))
                menu.go("list");
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

    // the popup's reply link opens the menu on the reply page
    Component.onCompleted: {
        if (Notifs.replying) {
            picked = Notifs.replying;
            Notifs.replying = null;
            go("reply");
        } else
            go("list");
    }
}
