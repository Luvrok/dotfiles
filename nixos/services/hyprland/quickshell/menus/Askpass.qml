import QtQuick
import qs

// rofi-askpass: a password prompt, hypr-askpass prints what was typed
Menu {
    id: menu

    signal answered(string text)

    password: true
    lines: 0
    padH: 8

    onAccepted: (index, text) => {
        hide();
        answered(text);
        done();
    }
    onCancelled: answered("")

    Component.onCompleted: show([])
}
