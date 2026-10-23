import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs

// the keys cheat sheet ($mod+/), the i3 eww keys menu in the menus' look.
// the pages are keys.conf: hyprland, librewolf, nvim. it opens on the page
// of the focused window. h/l, tab, 1-9, the wheel or a click on a tab flip
// pages, they slide like the calendar. / searches every page: the tabs
// count what matches and a page with nothing goes to one that has it
Menu {
    id: menu

    // [{name, classes, titles, secs: [{name, rows: [{keys, what, text}]}]}]
    property var pages: []
    property int page: 0
    // the last flip's direction, the page slides in from that side
    property int dir: 0
    readonly property int columns: 3
    // every word has to be in a row: its section, keys or what it does
    readonly property var words: text.toLowerCase().split(/\s+/).filter(w => w !== "")
    // the sections of every page with the rows that match
    readonly property var found: pages.map(p => p.secs.map(s => ({
                    name: s.name,
                    rows: s.rows.filter(r => words.every(w => r.text.includes(w)))
                })).filter(s => s.rows.length > 0))
    readonly property var counts: found.map(secs => secs.reduce((n, s) => n + s.rows.length, 0))
    readonly property var cols: split(found[page] ?? [])

    readonly property real rowH: Math.ceil(fm.height) + 6
    readonly property real titleH: Math.ceil(fm.height) + 4
    readonly property real secGap: 8
    // the widest row of all pages, so a flip doesn't change the width
    readonly property real colW: Math.max(ch(30), Math.ceil(pages.reduce((m, p) => p.secs.reduce((m, s) => s.rows.reduce((m, r) => Math.max(m, fm.advanceWidth(r.what) + 18 + r.keys.reduce((w, c) => w + capW(c), 0)), m), m), 0)) + 24)
    // the tallest page, the height stays too
    readonly property real bodyH: pages.reduce((m, p) => Math.max(m, ...split(p.secs).map(col => col.reduce((h, s) => h + secH(s), 0))), 0) + 4

    // a flip, the page slides
    signal flipped

    // keys.conf, the format is in its head
    function parse(conf) {
        const out = [];
        for (const raw of conf.split("\n")) {
            const l = raw.trim();
            if (l === "" || l.startsWith("#"))
                continue;
            const head = l.match(/^\[(.*)\]$/);
            if (head) {
                const w = head[1].trim().toLowerCase().split(/\s+/);
                out.push({
                    name: w[0],
                    classes: w.filter(x => !x.startsWith("~")),
                    titles: w.filter(x => x.startsWith("~")).map(x => x.slice(1)),
                    secs: []
                });
                continue;
            }
            // a row or a section before any page still goes somewhere
            if (out.length === 0)
                out.push({ name: "keys", classes: [], titles: [], secs: [] });
            const p = out[out.length - 1];
            const row = l.match(/^(.*?\S)(?:\s{2,}|\t)\s*(.*)$/);
            if (row) {
                if (p.secs.length === 0)
                    p.secs.push({ name: "", rows: [] });
                const sec = p.secs[p.secs.length - 1];
                sec.rows.push({
                    keys: keycaps(row[1]),
                    what: row[2],
                    text: `${sec.name} ${row[1]} ${row[2]}`.toLowerCase()
                });
            } else if (l.endsWith(":"))
                p.secs.push({ name: l.slice(0, -1), rows: [] });
        }
        return out;
    }

    // "mod+j / k" -> mod j / k: a keycap each, modifiers dim
    function keycaps(s) {
        const mods = ["mod", "shift", "ctrl", "alt", "leader"];
        const out = [];
        s.split(" / ").forEach((alt, i) => {
            if (i > 0)
                out.push({ t: "/", c: "sep" });
            for (const t of alt.split(/\+(?=.)/))
                out.push({ t: t, c: mods.includes(t) ? "mod" : "key" });
        });
        return out;
    }

    function capW(c) {
        return (c.c === "sep" ? capFm.advanceWidth(c.t) : capFm.advanceWidth(c.t) + 10) + 3;
    }

    function secH(s) {
        return secGap + (s.name !== "" ? titleH : 0) + s.rows.length * rowH;
    }

    // the sections in order into the columns, the tallest one as short as
    // it gets. each gets its place in the cascade
    function split(secs) {
        const n = secs.length, k = Math.min(columns, n);
        if (n === 0)
            return [];
        const pre = [0];
        for (const s of secs)
            pre.push(pre[pre.length - 1] + secH(s));
        // best[j][i]: the tallest column with the first i sections in j
        // columns, cut[j][i]: where the last one starts
        const best = [pre.slice()], cut = [[]];
        for (let j = 1; j < k; j++) {
            best.push([]);
            cut.push([]);
            for (let i = 0; i <= n; i++) {
                best[j][i] = Infinity;
                for (let m = j; m <= i; m++) {
                    const h = Math.max(best[j - 1][m], pre[i] - pre[m]);
                    if (h < best[j][i]) {
                        best[j][i] = h;
                        cut[j][i] = m;
                    }
                }
            }
        }
        const out = [];
        let end = n;
        for (let j = k - 1; j > 0; j--) {
            out.unshift(secs.slice(cut[j][end], end));
            end = cut[j][end];
        }
        out.unshift(secs.slice(0, end));
        let order = 0;
        return out.map(col => col.map(s => Object.assign({ order: order++ }, s)));
    }

    // the page of the focused window: its class, or a part of its title
    function startPage(list) {
        const t = Hyprland.activeToplevel;
        const cls = (t?.lastIpcObject?.class ?? t?.wayland?.appId ?? "").toLowerCase();
        const title = (t?.title ?? "").toLowerCase();
        return Math.max(0, list.findIndex(p => p.classes.includes(cls) || p.titles.some(w => title.includes(w))));
    }

    function go(i, step) {
        if (i === page || i < 0 || i >= pages.length)
            return;
        dir = step ?? Math.sign(i - page);
        page = i;
        flipped();
    }

    // wraps, while searching it skips pages with nothing found
    function flip(step) {
        const n = pages.length;
        for (let i = 1; i < n; i++) {
            const to = ((page + step * i) % n + n) % n;
            if (words.length === 0 || counts[to] > 0) {
                go(to, step);
                return;
            }
        }
    }

    title: "keys"
    icon: "\u{f030c}"
    status: words.length > 0 ? `${counts.reduce((n, c) => n + c, 0)} found` : ""
    searchable: true
    prompt: "search every page"
    lines: 0
    bodyUnder: true
    menuWidth: columns * colW + columns - 1 + 2
    hints: input ? [["enter", "list"], ["q", "back"], ["esc", "close"]] : [["h/l", "page"], ["/", "search"], ...(text !== "" ? [["q", "clear"]] : []), ["esc", "close"]]

    keys: e => {
        const k = e.key;
        // tab keeps the filter, Menu does that
        if (input)
            return false;
        const n = k - Qt.Key_1;
        if (k === Qt.Key_Left || k === Qt.Key_Backtab || key(e, "h"))
            flip(-1);
        else if (k === Qt.Key_Right || k === Qt.Key_Tab || key(e, "l"))
            flip(1);
        else if (n >= 0 && n < Math.min(9, pages.length) && !(e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)))
            go(n);
        else if (key(e, "q") && text !== "")
            closeSearch(false);
        else if (key(e, "q"))
            cancel();
        else
            return false;
        return true;
    }

    // enter in the search goes back to the pages with the filter
    onAccepted: closeSearch(true)

    // a match on another page when this one has none
    onWordsChanged: {
        if (words.length > 0 && counts[page] === 0) {
            const i = counts.findIndex(c => c > 0);
            if (i >= 0)
                go(i);
        }
    }

    body: Component {
        Item {
            id: body

            width: parent?.width ?? 0
            implicitHeight: tabs.y + tabs.height + menu.bodyH + 2
            clip: true

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton
                onWheel: w => menu.flip(w.angleDelta.y > 0 ? -1 : 1)
            }

            // the pages like the bar's tags, the orange block glides to the
            // open one. while searching they say how many rows match
            Item {
                id: tabs

                x: 12
                y: 2
                width: tabRow.width
                height: tabRow.height

                Rectangle {
                    readonly property Item at: tabRepeater.count > 0 ? tabRepeater.itemAt(menu.page) : null
                    visible: at !== null
                    x: at?.x ?? 0
                    width: at?.width ?? 0
                    height: tabRow.height
                    color: Theme.selBg
                    Behavior on x {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on width {
                        NumberAnimation {
                            duration: 120
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                Row {
                    id: tabRow

                    Repeater {
                        id: tabRepeater
                        model: menu.pages

                        delegate: Item {
                            id: tab
                            required property var modelData
                            required property int index
                            readonly property bool open: index === menu.page
                            readonly property bool none: menu.words.length > 0 && menu.counts[index] === 0

                            width: label.implicitWidth + 16
                            height: label.implicitHeight + 4

                            Text {
                                id: label
                                anchors.centerIn: parent
                                text: menu.words.length > 0 ? `${tab.modelData.name} ${menu.counts[tab.index]}` : tab.modelData.name
                                color: tab.open ? Theme.sel : tab.none ? Theme.line : Theme.dim
                                font: menu.rowFont
                                Behavior on color {
                                    ColorAnimation {
                                        duration: 120
                                    }
                                }
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: menu.go(tab.index)
                            }
                        }
                    }
                }
            }

            Item {
                id: content

                y: tabs.y + tabs.height + 2
                width: parent.width
                height: menu.bodyH
                transform: Translate {
                    id: shift
                }

                Row {
                    Repeater {
                        model: menu.cols

                        // a column, a line between it and the one before
                        delegate: Item {
                            id: col
                            required property var modelData
                            required property int index

                            width: menu.colW + (index > 0 ? 1 : 0)
                            height: content.height

                            Rectangle {
                                visible: col.index > 0
                                width: 1
                                height: parent.height
                                color: Theme.line
                            }

                            Column {
                                x: (col.index > 0 ? 1 : 0) + 12
                                width: menu.colW - 24

                                Repeater {
                                    model: col.modelData

                                    delegate: Section {}
                                }
                            }
                        }
                    }
                }

                Text {
                    anchors.centerIn: parent
                    visible: menu.cols.length === 0
                    text: "nothing found"
                    color: Theme.dim
                    font: menu.rowFont
                }
            }

            // like a tag switch: 6% from the side it comes from, with a fade
            ParallelAnimation {
                id: slide
                NumberAnimation {
                    target: shift
                    property: "x"
                    from: menu.dir * body.width * 0.06
                    to: 0
                    duration: 200
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: content
                    property: "opacity"
                    from: 0.3
                    to: 1
                    duration: 200
                    easing.type: Easing.OutCubic
                }
            }

            Connections {
                target: menu
                function onFlipped() {
                    slide.restart();
                }
            }
        }
    }

    // a section: its name in orange, then what each key does on the left
    // and the keys on the right. on open they come in one after another
    component Section: Column {
        id: sec

        required property var modelData

        width: parent?.width ?? 0
        topPadding: menu.secGap
        transform: Translate {
            id: drop
        }

        Component.onCompleted: {
            if (!menu.cascading)
                return;
            opacity = 0;
            drop.y = -6;
            intro.start();
        }

        SequentialAnimation {
            id: intro
            PauseAnimation {
                duration: sec.modelData.order * 35
            }
            ParallelAnimation {
                NumberAnimation {
                    target: sec
                    property: "opacity"
                    to: 1
                    duration: 160
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: drop
                    property: "y"
                    to: 0
                    duration: 160
                    easing.type: Easing.OutCubic
                }
            }
        }

        Text {
            visible: sec.modelData.name !== ""
            height: menu.titleH
            verticalAlignment: Text.AlignVCenter
            text: sec.modelData.name
            textFormat: Text.PlainText
            color: Theme.selBg
            font: menu.rowFont
        }

        Repeater {
            model: sec.modelData.rows

            delegate: Item {
                id: row
                required property var modelData

                width: sec.width
                height: menu.rowH

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - caps.width - 12
                    text: row.modelData.what
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: Theme.fg
                    font: menu.rowFont
                }

                Row {
                    id: caps
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Repeater {
                        model: row.modelData.keys

                        delegate: Keycap {}
                    }
                }
            }
        }
    }

    // a key: the key itself bright on the dark line, a modifier dim in a
    // frame, / between alternatives
    component Keycap: Rectangle {
        id: cap

        required property var modelData
        readonly property bool sep: modelData.c === "sep"

        width: sep ? label.implicitWidth : label.implicitWidth + 10
        height: label.implicitHeight + 2
        color: modelData.c === "key" ? Theme.line : "transparent"
        border.width: sep ? 0 : 1
        border.color: Theme.line

        Text {
            id: label
            anchors.centerIn: parent
            text: cap.modelData.t
            textFormat: Text.PlainText
            color: cap.modelData.c === "key" ? Theme.sel : Theme.dim
            font: capFm.font
        }
    }

    FontMetrics {
        id: fm
        font: menu.rowFont
    }

    // the keycaps' font, smaller like the hints
    FontMetrics {
        id: capFm
        font.family: Theme.font
        font.pointSize: 8
    }

    FileView {
        id: conf
        path: Quickshell.shellPath("keys.conf")
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        // after show: the sections made now come in one after another
        show([]);
        const list = parse(conf.text());
        page = startPage(list);
        pages = list;
    }
}
