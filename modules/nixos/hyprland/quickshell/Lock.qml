import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

// the lock screen (ext-session-lock): a big clock, the date and the
// password line on every monitor, drawn like the menus. the compositor
// gives the keys to one of them, typing goes there.
// pam checks it (security.pam.services.quickshell in default.nix). the
// shell locks it on `lock now` (loginctl lock-session, before sleep: the
// power menu's lock and swayidle in hyprland.lua)
Scope {
    id: root

    property bool locked: false
    // what pam said last: wrong password, a message
    property string message: ""
    property bool checking: false

    function lock() {
        message = "";
        locked = true;
    }

    function tryPassword(text) {
        if (text === "" || checking)
            return;
        checking = true;
        pending = text;
        if (pam.responseRequired)
            pam.respond(text);
        else
            pam.start();
    }

    property string pending: ""

    PamContext {
        id: pam
        config: "quickshell"
        onResponseRequiredChanged: {
            if (responseRequired && root.pending !== "") {
                respond(root.pending);
                root.pending = "";
            }
        }
        onCompleted: result => {
            root.checking = false;
            root.pending = "";
            if (result === PamResult.Success) {
                root.locked = false;
                root.message = "";
            } else
                root.message = result === PamResult.Failed ? "wrong password" : "pam failed";
        }
    }

    WlSessionLock {
        id: lock
        locked: root.locked

        WlSessionLockSurface {
            id: surface
            color: Theme.barBg

            SystemClock {
                id: clock
                precision: SystemClock.Seconds
            }

            Column {
                anchors.centerIn: parent
                spacing: 6

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    color: Theme.selBg
                    font.family: Theme.font
                    font.pointSize: 64
                    font.bold: true
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Qt.formatDateTime(clock.date, "dddd, d MMMM").toLowerCase()
                    color: Theme.dim
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize + 2
                }

                Item {
                    width: 1
                    height: 30
                }

                // the password line, like the menus' text line
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: 360
                    height: field.implicitHeight + 22
                    color: Theme.bg
                    border.width: 1
                    border.color: root.message !== "" ? Theme.urgent : Theme.border

                    Text {
                        id: arrow
                        x: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u{f033e}"
                        color: root.checking ? Theme.dim : Theme.selBg
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize + 1
                    }

                    TextInput {
                        id: field
                        x: arrow.x + arrow.implicitWidth + 10
                        width: parent.width - x - 12
                        anchors.verticalCenter: parent.verticalCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.fg
                        selectionColor: Theme.selBg
                        font.family: Theme.font
                        font.pointSize: Theme.fontSize + 1
                        focus: true
                        enabled: !root.checking
                        // the lock surface doesn't hand focus to its items
                        Component.onCompleted: forceActiveFocus()
                        onAccepted: {
                            root.tryPassword(text);
                            text = "";
                        }
                        Keys.onEscapePressed: text = ""

                        Text {
                            visible: field.text === ""
                            text: root.checking ? "checking…" : "password"
                            color: Theme.dim
                            font: field.font
                        }
                    }
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.message
                    color: Theme.urgent
                    font.family: Theme.font
                    font.pointSize: Theme.fontSize
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                text: [Quickshell.env("USER") ?? "", "locked"].filter(s => s !== "").join(" · ")
                color: Theme.dim
                font.family: Theme.font
                font.pointSize: 9
            }
        }
    }
}
