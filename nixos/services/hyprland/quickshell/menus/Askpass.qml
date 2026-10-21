import QtQuick
import qs

// rofi-askpass: a password prompt, hypr-askpass prints what was typed
Menu {
    id: menu

    signal answered(string text)

    title: "password"
    icon: "\u{f033e}"
    password: true
    lines: 0
    input: true
    enterHint: "send"

    onAccepted: (index, text) => {
        hide();
        answered(text);
        done();
    }
    onCancelled: answered("")

    Component.onCompleted: show([])
}
