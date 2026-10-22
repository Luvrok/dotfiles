import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Notifications

// the notification popup: one at a time, the newest (Notifs.current), at
// the bottom in the middle of the monitor that had focus, drawn like the
// menus. it goes after 5 s (3 s low, the app's own time if it sets one,
// else critical ones stay), the line at the bottom shows what's left and
// stops while the pointer is on it. left click: the default action, right
// click: away (it stays in the menu), middle: dismissed. hyprland slides
// it up from the bottom edge (layer rule for "notification")
PanelWindow {
    id: popup

    readonly property Notification n: Notifs.current
    readonly property bool critical: n?.urgency === NotificationUrgency.Critical
    // the countdown, 1 to 0
    property real left: 1
    // it just came up, hyprland slides it in
    property bool fresh: false
    readonly property string icon: {
        if (!n)
            return "";
        if (n.image !== "")
            return n.image;
        const name = n.appIcon;
        if (name.startsWith("/"))
            return `file://${name}`;
        return name.includes(":") ? name : name !== "" ? Quickshell.iconPath(name, true) : "";
    }
    readonly property real textX: icon !== "" ? 12 + 32 + 10 : 12

    // ms on screen, 0 for until it's clicked
    function timeout(n) {
        // the app's own, 0 is never. quickshell passes the ms through but
        // its doc says seconds, so a small one counts as seconds
        const t = n.expireTimeout;
        if (t === 0)
            return 0;
        if (t > 0)
            return Math.max(2000, Math.min(15000, t < 100 ? t * 1000 : t));
        return n.urgency === NotificationUrgency.Critical ? 0 : n.urgency === NotificationUrgency.Low ? 3000 : 5000;
    }

    function restart() {
        countdown.stop();
        left = 1;
        const ms = n ? timeout(n) : 0;
        if (ms > 0) {
            countdown.duration = ms;
            countdown.start();
        }
    }

    // on the focused monitor when it comes up, it stays there while it's up
    function follow() {
        if (!n) {
            countdown.stop();
            visible = false;
            return;
        }
        if (!visible) {
            screen = Hypr.focusedScreen();
            visible = true;
            fresh = true;
        }
    }

    visible: false
    color: "transparent"
    anchors.bottom: true
    margins.bottom: 15
    implicitWidth: Math.ceil(metrics.averageCharacterWidth * 56)
    implicitHeight: frame.height
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "notification"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    Connections {
        target: Notifs
        function onCurrentChanged() {
            popup.follow();
        }
        // a new one fades in over the one up, an update just changes
        function onPopped(same) {
            if (!same && !popup.fresh)
                swap.restart();
            popup.fresh = false;
            popup.restart();
        }
    }

    NumberAnimation {
        id: countdown
        target: popup
        property: "left"
        from: 1
        to: 0
        paused: running && mouse.containsMouse
        onFinished: Notifs.drop(popup.n)
    }

    // a newer one takes the place of the one up
    NumberAnimation {
        id: swap
        target: content
        property: "opacity"
        from: 0.3
        to: 1
        duration: 180
        easing.type: Easing.OutCubic
    }

    FontMetrics {
        id: metrics
        font.family: Theme.font
        font.pointSize: Theme.fontSize
    }

    Rectangle {
        id: frame
        width: parent.width
        height: Math.ceil(content.implicitHeight) + 2
        color: Theme.bg
        border.width: 1
        border.color: popup.critical ? Theme.urgent : Theme.border

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onClicked: e => {
                if (e.button === Qt.LeftButton)
                    Notifs.open(popup.n);
                else if (e.button === Qt.MiddleButton)
                    Notifs.dismiss(popup.n);
                else
                    Notifs.drop(popup.n);
            }
        }

        // an avatar or the app's icon
        IconImage {
            visible: popup.icon !== ""
            x: 12
            y: 9
            implicitSize: 32
            source: popup.icon
            asynchronous: true
        }

        Column {
            id: content
            x: 1
            y: 1
            width: parent.width - 2
            topPadding: 8
            bottomPadding: 8
            spacing: 4

            // the summary, the app and how many wait in the menu
            Item {
                width: parent.width
                height: summary.implicitHeight

                Text {
                    id: summary
                    x: popup.textX - 1
                    width: Math.max(0, parent.width - x - 12 - (app.implicitWidth > 0 ? app.implicitWidth + 12 : 0))
                    text: popup.n?.summary || popup.n?.appName || ""
                    textFormat: Text.PlainText
                    elide: Text.ElideRight
                    color: popup.critical ? Theme.urgent : Theme.selBg
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize
                    font.bold: true
                }

                Text {
                    id: app
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    readonly property int more: Notifs.list.filter(o => o !== popup.n).length
                    text: [popup.n?.summary ? popup.n?.appName ?? "" : "", more > 0 ? `+${more}` : ""].filter(s => s !== "").join(" · ")
                    textFormat: Text.PlainText
                    color: Theme.dim
                    font: metrics.font
                }
            }

            Text {
                visible: text !== ""
                x: popup.textX - 1
                width: parent.width - x - 12
                text: Notifs.styled(popup.n?.body ?? "")
                textFormat: Text.StyledText
                wrapMode: Text.Wrap
                maximumLineCount: 5
                elide: Text.ElideRight
                color: Theme.fg
                linkColor: Theme.selBg
                font: metrics.font
            }

            // a progress: volume, brightness
            Item {
                id: progress
                readonly property var value: popup.n?.hints.value
                visible: value !== undefined
                x: popup.textX - 1
                width: parent.width - x - 12
                height: 9

                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 3
                    color: Theme.line

                    Rectangle {
                        width: Math.round(track.width * Math.max(0, Math.min(100, progress.value ?? 0)) / 100)
                        height: parent.height
                        color: Theme.selBg
                        Behavior on width {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }

            // the actions but the default one, the click takes them. reply
            // opens the menu's text line for it
            Flow {
                readonly property var acts: [...(popup.n?.hasInlineReply ? [{
                            text: popup.n.inlineReplyPlaceholder || "reply",
                            reply: true
                        }] : []), ...(popup.n?.actions ?? []).filter(a => a.identifier !== "default" && a.identifier !== "inline-reply" && a.text !== "")]
                visible: acts.length > 0
                x: popup.textX - 1
                width: parent.width - x - 12
                spacing: 4

                Repeater {
                    model: parent.acts

                    delegate: Text {
                        required property var modelData
                        required property int index
                        text: index > 0 ? `· ${modelData.text}` : modelData.text
                        color: act.containsMouse ? Theme.selBg : Theme.fg
                        font.family: Theme.font
                        font.pointSize: 8

                        MouseArea {
                            id: act
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (parent.modelData.reply)
                                    Notifs.reply(popup.n);
                                else
                                    parent.modelData.invoke();
                            }
                        }
                    }
                }
            }

            // what's left of its time, the menus' hairline running out. a
            // progress has its own bar
            Item {
                visible: countdown.running && popup.n?.hints.value === undefined
                width: parent.width
                height: 5

                Rectangle {
                    x: 11
                    anchors.bottom: parent.bottom
                    width: parent.width - 22
                    height: 1
                    color: Theme.line

                    Rectangle {
                        width: Math.round(parent.width * popup.left)
                        height: 1
                        color: Theme.selBg
                    }
                }
            }
        }
    }
}
