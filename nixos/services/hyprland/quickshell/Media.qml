pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// the player the bar and the player menu show (mpris: mpv, the browser,
// spotify): the one picked in the menu while it's there, else the one
// playing, else the first. cava gives the visualizer's 24 levels while
// something plays, nothing runs otherwise
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer chosen: null
    readonly property MprisPlayer player: players.includes(chosen) ? chosen : players.find(p => p.isPlaying) ?? players[0] ?? null
    readonly property bool playing: player?.isPlaying ?? false
    // 0..1 each, low to high
    property var levels: []

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
