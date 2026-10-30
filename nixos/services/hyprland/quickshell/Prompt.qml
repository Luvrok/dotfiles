pragma Singleton

import QtQuick
import Quickshell

// a password prompt is up (Askpass.qml): the menu that started it hides
// under it and comes back with the state it had, after the prompt is done
Singleton {
    property bool active: false
}
