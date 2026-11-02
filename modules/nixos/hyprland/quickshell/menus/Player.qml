import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.widgets

// the player (Media.qml): the cover, the track, a bar to seek with the
// mouse, the time, a big visualizer under it, the other players if there
// are more. space plays and pauses, n/p next and previous, h/l seek 10 s,
// tab the next player, a goes to the audio menu (its p comes back)
Menu {
    id: menu

    readonly property MprisPlayer player: Media.player

    function seek(by) {
        if (!player?.canSeek)
            return;
        player.position = Math.max(0, Math.min(player.length, player.position + by));
    }

    title: "player"
    icon: "\u{f075a}"
    status: player ? player.identity : ""
    statusAccent: Media.playing
    lines: 0
    menuWidth: ch(80)
    hints: [["space", Media.playing ? "pause" : "play"], ["n/p", "next / previous"], ["h/l", "seek"], ...(Media.players.length > 1 ? [["tab", "player"]] : []), ["a", "audio"], ...upHint, ["esc", "close"]]

    keys: e => {
        const k = e.key;
        if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter)
            player?.togglePlaying();
        else if (key(e, "n"))
            player?.next();
        else if (key(e, "p"))
            player?.previous();
        else if (k === Qt.Key_Left || key(e, "h"))
            seek(-10);
        else if (k === Qt.Key_Right || key(e, "l"))
            seek(10);
        else if (k === Qt.Key_Tab)
            Media.next();
        else if (key(e, "a"))
            goTo("audio");
        else
            return false;
        return true;
    }

    body: Component {
        Column {
            id: page
            width: parent?.width ?? 0
            topPadding: 4
            bottomPadding: 6
            spacing: 8

            readonly property MprisPlayer p: menu.player

            Text {
                visible: !page.p
                x: 12
                text: "nothing plays"
                color: Theme.dim
                font: menu.rowFont
            }

            Row {
                visible: page.p !== null
                x: 12
                width: parent.width - 24
                spacing: 12

                // the cover, a note when there's none
                Rectangle {
                    width: 88
                    height: 88
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.line

                    Text {
                        anchors.centerIn: parent
                        visible: cover.status !== Image.Ready
                        text: "\u{f0387}"
                        color: Theme.dim
                        font.family: Theme.font
                        font.pointSize: 24
                    }

                    Image {
                        id: cover
                        anchors.fill: parent
                        anchors.margins: 1
                        source: page.p?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                    }
                }

                Column {
                    width: parent.width - 88 - 12
                    spacing: 3

                    Text {
                        width: parent.width
                        text: page.p?.trackTitle || page.p?.identity || ""
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.selBg
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize + 1
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        text: [page.p?.trackArtist ?? "", page.p?.trackAlbum ?? ""].filter(s => s !== "").join(" · ")
                        textFormat: Text.PlainText
                        elide: Text.ElideRight
                        color: Theme.dim
                        font: menu.rowFont
                    }

                    Item {
                        width: 1
                        height: 14
                    }

                    // the seek bar: a click or a drag goes there
                    MouseArea {
                        id: seekMouse
                        width: parent.width
                        height: 12
                        enabled: page.p?.canSeek ?? false
                        hoverEnabled: true
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onPressed: e => page.p.position = page.p.length * Math.max(0, Math.min(1, e.x / width))
                        onPositionChanged: e => {
                            if (pressed)
                                page.p.position = page.p.length * Math.max(0, Math.min(1, e.x / width));
                        }

                        Rectangle {
                            id: track
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width
                            height: seekMouse.containsMouse ? 5 : 3
                            color: Theme.line

                            Rectangle {
                                width: page.p && page.p.length > 0 ? Math.round(track.width * Math.min(1, page.p.position / page.p.length)) : 0
                                height: parent.height
                                color: Theme.selBg
                            }
                        }
                    }

                    Item {
                        width: parent.width
                        height: timeText.implicitHeight

                        Text {
                            id: timeText
                            text: page.p?.lengthSupported ? `${Media.time(page.p.position)} / ${Media.time(page.p.length)}` : ""
                            color: Theme.fg
                            font: menu.rowFont
                        }
                        Text {
                            anchors.right: parent.right
                            text: page.p ? (page.p.isPlaying ? "\u{f03e4}" : "\u{f040a}") : ""
                            color: Theme.selBg
                            font: menu.rowFont

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: page.p?.togglePlaying()
                            }
                        }
                    }
                }
            }

            Visualizer {
                visible: page.p !== null
                x: 12
                width: parent.width - 24
                height: 44
                count: 24
                gap: 3
            }

            // the players, the shown one orange, a click picks one
            Flow {
                visible: Media.players.length > 1
                x: 12
                width: parent.width - 24
                spacing: 12

                Repeater {
                    model: Media.players

                    delegate: Text {
                        required property var modelData
                        text: modelData.identity
                        color: modelData === page.p ? Theme.selBg : Theme.dim
                        font: menu.rowFont

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: Media.chosen = parent.modelData
                        }
                    }
                }
            }
        }
    }

    Component.onCompleted: {
        Media.watched = true;
        show([]);
    }
    Component.onDestruction: Media.watched = false
}
