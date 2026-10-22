pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// the player the bar and the player menu show (mpris: feishin, mpv, the
// browser): the one picked in the menu with tab, until another one starts.
// else what plays before what doesn't, a browser after the rest (music
// stays on top of a youtube tab, the tab shows when nothing else plays),
// then the one that started last. cava gives the visualizer's 24 levels
// while something plays, nothing runs otherwise
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer chosen: null
    // when each one last started playing, by dbus name
    property var started: ({})
    readonly property MprisPlayer player: {
        if (players.includes(chosen))
            return chosen;
        const rank = p => (p.isPlaying ? 0 : 2) + (browser(p) ? 1 : 0);
        return players.slice().sort((a, b) => rank(a) - rank(b) || (started[b.dbusName] ?? 0) - (started[a.dbusName] ?? 0) || a.dbusName.localeCompare(b.dbusName))[0] ?? null;
    }
    readonly property bool playing: player?.isPlaying ?? false
    // 0..1 each, low to high
    property var levels: []

    function mark(p) {
        started = Object.assign({}, started, {
            [p.dbusName]: Date.now()
        });
        if (chosen !== p)
            chosen = null;
    }

    function browser(p) {
        return /firefox|librewolf|chrom|brave|vivaldi|opera|edge|zen|plasma-browser/i.test(`${p.identity} ${p.desktopEntry} ${p.dbusName}`);
    }

    function next() {
        if (players.length < 2)
            return;
        chosen = players[(players.indexOf(player) + 1) % players.length];
    }

    function time(s) {
        if (!(s >= 0))
            return "0:00";
        const m = Math.floor(s / 60);
        const h = Math.floor(m / 60);
        const ss = String(Math.floor(s % 60)).padStart(2, "0");
        return h > 0 ? `${h}:${String(m % 60).padStart(2, "0")}:${ss}` : `${m}:${ss}`;
    }

    // n levels out of the 24, each the loudest of its group
    function bars(n) {
        const out = [];
        const per = levels.length / n;
        for (let i = 0; i < n; i++) {
            let v = 0;
            for (let j = Math.floor(i * per); j < Math.floor((i + 1) * per); j++)
                v = Math.max(v, levels[j] ?? 0);
            out.push(v);
        }
        return out;
    }

    // a player that starts takes the bar, even from one picked by hand
    Variants {
        model: Mpris.players.values

        // one that shows up playing starts too
        Connections {
            required property MprisPlayer modelData
            target: modelData
            function onIsPlayingChanged() {
                if (modelData.isPlaying)
                    root.mark(modelData);
            }
            Component.onCompleted: {
                if (modelData.isPlaying)
                    root.mark(modelData);
            }
        }
    }

    // mpris doesn't send the position as it moves, ask once a second
    Timer {
        interval: 1000
        repeat: true
        running: root.playing
        onTriggered: root.player?.positionChanged()
    }

    Process {
        running: root.playing
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        stdout: SplitParser {
            onRead: line => root.levels = line.split(";").filter(v => v !== "").map(v => Math.min(1, parseInt(v) / 100))
        }
        onRunningChanged: {
            if (!running)
                root.levels = [];
        }
    }
}
