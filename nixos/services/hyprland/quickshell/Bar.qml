import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire

// dwm-like bar, the twin of nixos/services/sway/eww: tags, layout, window
// titles, status. top layer, hyprland hides it under fullscreen windows
PanelWindow {
    id: bar

    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)
    readonly property HyprlandWorkspace ws: monitor?.activeWorkspace ?? null
    readonly property int offset: Hypr.offset(monitor?.name ?? "")

    function dispatch(lua) {
        Hyprland.dispatch(lua);
    }

    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    color: Theme.barBg
    WlrLayershell.namespace: "bar"

    component Label: Text {
        color: Theme.fg
        font.family: Theme.barFont
        font.pointSize: Theme.barFontSize
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
                const labels = ["scl", "obs", "sh1", "sh2", "smth", "virt", "med", "smth", "vpn"];
                const tags = [];
                for (let i = 1; i <= 9; i++)
                    tags.push({ id: bar.offset + i, label: labels[i - 1] });
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
                    leftPadding: 9
                    rightPadding: 9
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
                            bar.dispatch(`hl.dsp.focus({ workspace = ${id} })`);
                    }
                }
            }
        }

        // 󰓒 master, [n] monocle with n windows, nothing on an empty monocle tag
        Label {
            leftPadding: 6
            rightPadding: 6
            text: {
                const ws = bar.ws;
                if (!ws)
                    return "";
                if (ws.lastIpcObject.tiledLayout !== "monocle")
                    return "\u{f04d2}";
                const n = Hyprland.toplevels.values.filter(t => t.workspace === ws && !t.lastIpcObject.floating).length;
                return n > 0 ? `[${n}]` : "";
            }
        }

        // windows on the open tag, master then the stack, floating last.
        // equal width, orange is the last focused one of this monitor
        Item {
            id: titles

            readonly property var windows: {
                const ws = bar.ws;
                if (!ws)
                    return [];
                const key = t => {
                    const o = t.lastIpcObject;
                    return [o.floating ? 1 : 0, o.at?.[0] ?? 0, o.at?.[1] ?? 0];
                };
                return Hyprland.toplevels.values.filter(t => t.workspace === ws).sort((a, b) => {
                    const ka = key(a), kb = key(b);
                    return ka[0] - kb[0] || ka[1] - kb[1] || ka[2] - kb[2];
                });
            }
            readonly property string last: (bar.ws?.lastIpcObject.lastwindow ?? "").replace(/^0x/, "")

            Layout.fillWidth: true
            Layout.fillHeight: true

            Row {
                anchors.fill: parent

                Repeater {
                    model: titles.windows

                    delegate: Item {
                        id: win

                        required property HyprlandToplevel modelData
                        readonly property string address: modelData.address.replace(/^0x/, "")
                        readonly property bool selected: address === titles.last

                        width: titles.width / titles.windows.length
                        height: titles.height

                        Rectangle {
                            anchors.fill: parent
                            color: win.selected ? Theme.selBg : winMouse.containsMouse ? Theme.hover : "transparent"
                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }
                        }

                        Label {
                            width: parent.width
                            leftPadding: 6
                            rightPadding: 6
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                            text: win.modelData.title
                            color: win.selected ? Theme.sel : Theme.fg
                        }

                        MouseArea {
                            id: winMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: bar.dispatch(`hl.dsp.focus({ window = "address:0x${win.address}" })`)
                        }
                    }
                }
            }
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

            // volume: scroll ±2% unless muted, middle click mutes
            Label {
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
                    acceptedButtons: Qt.MiddleButton
                    onClicked: parent.sink.audio.muted = !parent.sink.audio.muted
                    onWheel: w => {
                        const audio = parent.sink?.audio;
                        if (!audio || audio.muted)
                            return;
                        const v = parent.volume + (w.angleDelta.y > 0 ? 2 : -2);
                        audio.volume = Math.max(0, Math.min(100, v)) / 100;
                    }
                }
            }
            Sep {}

            // memory, like `free -h`: left click opens btop
            Label {
                id: memory
                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["kitty", "-e", "btop"])
                }
                Process {
                    id: free
                    running: true
                    command: ["free", "-h"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            const mem = text.split("\n").find(l => l.startsWith("Mem"))?.split(/\s+/);
                            if (mem)
                                memory.text = `${mem[2]}/${mem[1]}`.replace(/i/g, "").replace(/,/g, ".");
                        }
                    }
                }
            }
            Sep {}

            // wifi signal, hidden without wlan0 (barnard has none)
            Label {
                id: wifi
                visible: text !== ""
                Process {
                    id: iwctl
                    running: true
                    command: ["sh", "-c", "[ -e /sys/class/net/wlan0 ] && iwctl station wlan0 show"]
                    stdout: StdioCollector {
                        onStreamFinished: {
                            if (text === "") {
                                wifi.text = "";
                                return;
                            }
                            const line = text.split("\n").find(l => /RSSI/.test(l) && !/Average/.test(l));
                            const rssi = parseInt(line?.trim().split(/\s+/)[1]);
                            wifi.text = isNaN(rssi) ? "\u{f092b}" : rssi >= -50 ? "\u{f0928}" : rssi >= -60 ? "\u{f0925}" : rssi >= -70 ? "\u{f0922}" : rssi >= -80 ? "\u{f091f}" : "\u{f092b}";
                        }
                    }
                }
            }
            Sep {
                visible: wifi.visible
            }

            // date: right click shows a calendar
            Label {
                text: Qt.formatDateTime(clock.date, "dd.MM.yyyy | HH:mm")
                SystemClock {
                    id: clock
                    precision: SystemClock.Minutes
                }
                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.RightButton
                    onClicked: Quickshell.execDetached(["kitty", "--hold", "-e", "cal", "-3"])
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
            free.running = true;
            iwctl.running = true;
        }
    }
}
