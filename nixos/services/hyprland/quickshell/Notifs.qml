pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// the notification server, instead of dunst (it stays for i3 and sway, its
// unit doesn't start under hyprland). one popup at a time, the newest, the
// rest wait in the notifications menu until they're dismissed or their app
// takes them back. a progress (the value hint: volume, brightness), a low
// one with a stack tag (volume: mute) and a transient one only pop up. one
// with the same stack tag as an older one of its app takes its place, in
// the popup too: it stays up and changes, its time starts over
Singleton {
    id: root

    // the popup's, null while it's down
    property Notification current: null
    // no popups but critical ones, the menu gets them all the same
    property bool quiet: false
    // when each came or changed, by id
    property var times: ({})
    property int stamp: 0
    // the menu's, newest first
    readonly property var list: {
        stamp;
        return server.trackedNotifications.values.filter(n => !passing(n)).sort((a, b) => (times[b.id] ?? 0) - (times[a.id] ?? 0) || b.id - a.id);
    }
    readonly property int count: list.length

    // it pops up again, even when it's the one up already. same: it took
    // the place of the one up (an update, the same stack tag)
    signal popped(bool same)

    function tag(n) {
        const h = n.hints;
        return String(h["x-dunst-stack-tag"] ?? h["x-canonical-private-synchronous"] ?? h["private-synchronous"] ?? h["synchronous"] ?? "");
    }

    // shown while it pops up only
    function passing(n) {
        return n.transient || n.hints.value !== undefined || (n.urgency === NotificationUrgency.Low && tag(n) !== "");
    }

    function add(n) {
        n.tracked = true;
        const t = tag(n);
        const older = t === "" ? [] : server.trackedNotifications.values.filter(o => o.appName === n.appName && tag(o) === t);
        // the popup moves on to it before the old one goes, so it stays up
        const same = older.includes(current);
        if (same)
            current = n;
        for (const o of older)
            o.dismiss();
        // the menu keeps 50
        for (const o of list.slice(49))
            o.expire();
        // carried over from before a reload, no popup
        if (n.lastGeneration)
            note(n);
        else
            raise(n, same);
    }

    function note(n) {
        times[n.id] = Date.now();
        stamp++;
    }

    function raise(n, same) {
        note(n);
        if (quiet && n.urgency !== NotificationUrgency.Critical) {
            if (passing(n))
                n.expire();
            return;
        }
        const up = current === n;
        current = n;
        popped(same || up);
    }

    // the popup is done with it: time's up or clicked away
    function drop(n) {
        if (!n)
            return;
        if (current === n)
            current = null;
        if (passing(n))
            n.expire();
    }

    // its default action, or the only one. invoking dismisses it unless
    // it's resident
    function open(n) {
        if (!n)
            return;
        const a = n.actions.find(a => a.identifier === "default") ?? (n.actions.length === 1 ? n.actions[0] : null);
        if (!a) {
            drop(n);
            return;
        }
        if (current === n)
            current = null;
        a.invoke();
    }

    function dismiss(n) {
        if (!n)
            return;
        if (current === n)
            current = null;
        n.dismiss();
    }

    function clear() {
        current = null;
        for (const n of server.trackedNotifications.values)
            n.dismiss();
    }

    // the body as one line of plain text, for the menu
    function plain(s) {
        return s.replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&apos;|&#39;/g, "'").replace(/&amp;/g, "&").replace(/\s+/g, " ").trim();
    }

    // the body for a Text in StyledText: no images, line breaks kept
    function styled(s) {
        return s.replace(/<img[^>]*>/gi, "").trim().replace(/\n/g, "<br>");
    }

    NotificationServer {
        id: server
        keepOnReload: true
        persistenceSupported: true
        bodyMarkupSupported: true
        actionsSupported: true
        imageSupported: true
        onNotification: n => root.add(n)
    }

    // a notification the app sends again with the same id is updated in
    // place, it pops up again
    Variants {
        model: server.trackedNotifications.values

        Connections {
            id: watch
            required property Notification modelData
            target: modelData
            function onSummaryChanged() {
                root.raise(watch.modelData);
            }
            function onBodyChanged() {
                root.raise(watch.modelData);
            }
            function onHintsChanged() {
                root.raise(watch.modelData);
            }
            function onClosed() {
                if (root.current === watch.modelData)
                    root.current = null;
                root.stamp++;
            }
        }
    }
}
