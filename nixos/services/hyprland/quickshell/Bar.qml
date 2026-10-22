import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// dwm-like bar, the twin of nixos/services/sway/eww: tags, the windows of
// the open tag as squares, status. hyprland hides it under fullscreen
// windows
PanelWindow {
    id: bar

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property HyprlandWorkspace ws: monitor?.activeWorkspace ?? null
    readonly property int offset: Hypr.offset(monitor?.name ?? "")

    // a menu on this monitor: the system one, the calendar
    signal openMenu(string name)

    function dispatch(lua) {
        Hyprland.dispatch(lua);
    }

    // focus without moving the cursor. hyprland warps it to the middle of
    // the window it focuses, or of the monitor a tag lives on, so it goes
    // back to the click right after, like i3's mouse_warping output
    function focus(lua) {
        Hyprland.dispatch(`function() local p = hl.get_cursor_pos(); hl.dispatch(${lua}); if p then hl.dispatch(hl.dsp.cursor.move({ x = p.x, y = p.y })) end end`);
    }

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.barBg
    WlrLayershell.namespace: "bar"
    // under the windows: a floating window can cover it
    WlrLayershell.layer: WlrLayer.Bottom

    component Label: Text {
        color: Theme.fg
        font.family: Theme.barFont
        font.pixelSize: Theme.barFontSize
        verticalAlignment: Text.AlignVCenter
        height: bar.height
    }

    component Sep: Label {
        leftPadding: 6
        rightPadding: 6
        text: "|"
    }

    RowLayout {
        anchors.fill: parent
        spacing: 0

        // tags 1-9 of this monitor
        // orange: open here, square: has windows, filled square: focused
        // left click: go there, right click: move the window there
        Repeater {
            model: {
                const tags = [];
                for (let i = 1; i <= 9; i++)
                    tags.push({ id: bar.offset + i, label: Hypr.labels[i - 1] });
                // workspaces left here by an unplugged monitor, so their windows don't get lost
                for (const w of Hyprland.workspaces.values)
                    if (w.monitor === bar.monitor && w.id > 0 && (w.id <= bar.offset || w.id > bar.offset + 9))
                        tags.push({ id: w.id, label: w.name });
                return tags;
            }

            delegate: Item {
                id: tag

                required property var modelData
                readonly property HyprlandWorkspace workspace: Hyprland.workspaces.values.find(w => w.id === modelData.id) ?? null
                readonly property bool selected: bar.ws?.id === modelData.id
                readonly property bool focused: selected && (bar.monitor?.focused ?? false)
                readonly property bool urgent: workspace?.urgent ?? false
                readonly property bool occupied: (workspace?.toplevels.values.length ?? 0) > 0

                Layout.fillHeight: true
                implicitWidth: tagLabel.implicitWidth

                Rectangle {
                    anchors.fill: parent
                    color: tag.urgent ? Theme.urgent : tag.selected ? Theme.selBg : tagMouse.containsMouse ? Theme.hover : "transparent"
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                Label {
                    id: tagLabel
                    leftPadding: 11
                    rightPadding: 11
                    text: tag.modelData.label
                    color: tag.selected || tag.urgent ? Theme.sel : Theme.fg
                }

                Rectangle {
                    visible: tag.occupied
                    x: 2
                    y: 2
                    width: 5
                    height: 5
                    color: tag.focused ? Theme.sel : "transparent"
                    border.width: 1
                    border.color: tag.selected ? Theme.sel : Theme.fg
                }

                MouseArea {
                    id: tagMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: e => {
                        const id = tag.modelData.id;
                        if (e.button === Qt.RightButton)
                            bar.dispatch(`hl.dsp.window.move({ workspace = ${id}, follow = false })`);
                        else
                            bar.focus(`hl.dsp.focus({ workspace = ${id} })`);
                    }
                }
            }
        }

        // the windows of the open tag, a square each: master, the stack,
        // floating last, top to bottom in 3 rows, then the next column, up
        // to 30. filled is the tag's last focused one. click focuses one,
        // the wheel goes to the next or the previous one
        Item {
            id: windows

            readonly property int size: 4
            // the same space above, between and under the rows
            readonly property int gap: Math.floor((bar.height - 3 * size) / 4)
            readonly property int pad: 8
            readonly property var list: {
                const ws = bar.ws;
                if (!ws)
                    return [];
                const key = t => {
                    const o = t.lastIpcObject;
                    return [o.floating ? 1 : 0, o.at?.[0] ?? 0, o.at?.[1] ?? 0];
                };
                // a total order, sort() isn't stable here
                return Hyprland.toplevels.values.filter(t => t.workspace === ws).sort((a, b) => {
                    const ka = key(a), kb = key(b);
                    return ka[0] - kb[0] || ka[1] - kb[1] || ka[2] - kb[2] || a.address.localeCompare(b.address);
                }).slice(0, 30);
            }
            readonly property string last: (bar.ws?.lastIpcObject.lastwindow ?? "").replace(/^0x/, "")

            function address(t) {
                return t.address.replace(/^0x/, "");
            }

            function focusAt(i) {
                const n = list.length;
                if (n > 0)
                    bar.focus(`hl.dsp.focus({ window = "address:0x${address(list[(i % n + n) % n])}" })`);
            }

            Layout.fillHeight: true
            implicitWidth: list.length > 0 ? 2 * pad + Math.ceil(list.length / 3) * (size + gap) - gap : 0

            MouseArea {
                anchors.fill: parent
                onWheel: w => windows.focusAt(windows.list.findIndex(t => windows.address(t) === windows.last) + (w.angleDelta.y > 0 ? -1 : 1))
            }

            Repeater {
                model: windows.list

                delegate: Rectangle {
                    id: square

                    required property int index
                    required property HyprlandToplevel modelData
                    readonly property bool active: windows.address(modelData) === windows.last

                    x: windows.pad + Math.floor(index / 3) * (windows.size + windows.gap)
                    y: windows.gap + index % 3 * (windows.size + windows.gap)
                    width: windows.size
                    height: windows.size
                    color: active ? Theme.fg : "transparent"
                    border.width: 1
                    border.color: squareMouse.containsMouse ? Theme.selBg : Theme.fg

                    // a new one fades in, the rest glide to their new place
                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 150
                        }
                    }
                    Behavior on x {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                        }
                    }

                    // the gap around it counts, a 4px square is a small target
                    MouseArea {
                        id: squareMouse
                        anchors.centerIn: parent
                        width: windows.size + windows.gap
                        height: windows.size + windows.gap
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: windows.focusAt(square.index)
                    }
                }
            }
        }

        // the free middle
        Item {
            Layout.fillWidth: true
        }

        // status
        Row {
            Layout.fillHeight: true
            rightPadding: 6
            leftPadding: 6

            // keyboard: left click switches
            Label {
                text: ` [${Hypr.layout}]`
                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["hyprctl", "switchxkblayout", "current", "next"])
                }
            }
            Sep {}

            // the switches that are on (vpn, zapret, dnscrypt), a click opens
            // the switches menu
            Label {
                id: switches
                readonly property var on: Toggles.list.filter(t => Toggles.isOn(t.id))
                visible: on.length > 0
                text: on.map(t => t.icon).join(" ")
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.openMenu("switches")
                }
            }
            Sep {
                visible: switches.visible
            }

            // notifications that wait, a crossed bell while the popups are
            // off. left click: the menu, right: popups off and on, middle:
            // clear
            Label {
                id: bell
                visible: Notifs.count > 0 || Notifs.quiet
                text: (Notifs.quiet ? "\u{f009b}" : "\u{f009a}") + (Notifs.count > 0 ? ` ${Notifs.count}` : "")
                color: Notifs.quiet ? Theme.dim : Theme.fg
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => {
                        if (e.button === Qt.RightButton)
                            Notifs.quiet = !Notifs.quiet;
                        else if (e.button === Qt.MiddleButton)
                            Notifs.clear();
                        else
                            bar.openMenu("notifications");
                    }
                }
            }
            Sep {
                visible: bell.visible
            }

            // volume: scroll ±2% unless muted, middle click mutes, a click
            // opens the mixer (the audio menu)
            Label {
                id: sound
                readonly property PwNode sink: Pipewire.defaultAudioSink
                readonly property int volume: Math.round((sink?.audio?.volume ?? 0) * 100)

                PwObjectTracker {
                    objects: [Pipewire.defaultAudioSink]
                }

                text: {
                    if (!sink?.audio)
                        return "";
                    if (sink.audio.muted)
                        return "";
                    const icon = volume > 40 ? "" : volume > 15 ? "" : "";
                    return `${icon} ${volume}%`;
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => {
                        if (e.button === Qt.LeftButton)
                            bar.openMenu("audio");
                        else
                            parent.sink.audio.muted = !parent.sink.audio.muted;
                    }
                    onWheel: w => {
                        const audio = parent.sink?.audio;
                        if (!audio || audio.muted)
                            return;
                        const v = parent.volume + (w.angleDelta.y > 0 ? 2 : -2);
                        audio.volume = Math.max(0, Math.min(100, v)) / 100;
                    }
                }
            }
            Sep {
                visible: sound.text !== ""
            }

            // memory in use, like `free -h`: left click opens the system
            // menu, right click btop
            Label {
                id: memory

                // kB, free's way: 692M, 5.2G, 15G
                function size(kb) {
                    const g = kb / 1048576;
                    return g >= 10 ? `${Math.floor(g)}G` : g >= 1 ? `${g.toFixed(1)}G` : `${Math.floor(kb / 1024)}M`;
                }

                function parse(text) {
                    const kb = name => parseInt(text.match(new RegExp(`^${name}:\\s+(\\d+)`, "m"))?.[1]);
                    const total = kb("MemTotal"), avail = kb("MemAvailable");
                    if (!isNaN(total) && !isNaN(avail))
                        memory.text = `${size(total - avail)}/${size(total)}`;
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: e => {
                        if (e.button === Qt.RightButton)
                            Quickshell.execDetached(["kitty", "-e", "btop"]);
                        else
                            bar.openMenu("system");
                    }
                }
                FileView {
                    id: meminfo
                    path: "/proc/meminfo"
                    onLoaded: memory.parse(text())
                }
            }
            Sep {}

            // wifi signal from iwd (scripts/wifi), hidden while offline or
            // without wifi (barnard has none)
            Label {
                id: wifi
                visible: text !== ""
                Process {
                    id: iwd
                    running: true
                    command: ["bash", Quickshell.shellPath("scripts/wifi"), "signal"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            // dbm * 100
                            const dbm = parseInt(text) / 100;
                            wifi.text = isNaN(dbm) ? "" : dbm >= -50 ? "\u{f0928}" : dbm >= -60 ? "\u{f0925}" : dbm >= -70 ? "\u{f0922}" : dbm >= -80 ? "\u{f091f}" : "\u{f092b}";
                        }
                    }
                }
            }
            Sep {
                visible: wifi.visible
            }

            // date: a click opens the calendar
            Label {
                text: Qt.formatDateTime(clock.date, "dd.MM.yyyy | HH:mm")
                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.openMenu("calendar")
                }
            }
        }
    }

    // memory and wifi every 10 s, volume and the rest update on their own
    Timer {
        interval: 10000
        running: true
        repeat: true
        onTriggered: {
            meminfo.reload();
            iwd.running = true;
        }
    }
}
