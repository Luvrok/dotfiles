import QtQuick
import qs

// rofi-askpass and pinentry: a password prompt (pin), a yes or no
// (confirm) or a message to close. hypr-askpass and hypr-pinentry print
// what answered says: the password, "yes" or "ok", "" for esc. note is
// what gpg tells about the key, error why it asks again
Menu {
    id: menu

    property string kind: "pin"
    property string error: ""

    signal answered(string text)

    function finish(text) {
        hide();
        answered(text);
        done();
    }

    title: kind === "pin" ? "password" : "gpg"
    icon: kind === "pin" ? "\u{f033e}" : "\u{f02fd}"
    status: error
    statusAccent: error !== ""
    password: kind === "pin"
    input: kind === "pin"
    lines: 0
    hints: kind === "pin" ? [["enter", "send"], ["esc", "cancel"]] : kind === "confirm" ? [["enter", "yes"], ["esc", "no"]] : [["enter", "ok"]]

    // confirm and message have no text line, enter comes here
    keys: e => {
        if (e.key !== Qt.Key_Return && e.key !== Qt.Key_Enter)
            return false;
        finish(kind === "confirm" ? "yes" : "ok");
        return true;
    }

    onAccepted: (index, text) => finish(text)
    onCancelled: answered(kind === "message" ? "ok" : "")

    Component.onCompleted: show([])
}
