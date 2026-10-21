pragma Singleton

import QtQuick
import Quickshell

// gruvbox, the same as home/programs/rofi/config/colors.rasi and the eww bar
Singleton {
    // menus
    readonly property color bg: "#e6171717"
    readonly property color fg: "#ebdbb2"
    readonly property color border: "#d65d0e"
    readonly property color sel: "#fbf1c7"
    readonly property color selBg: "#d65d0e"
    // fg at 45% and the dark line, like the eww wifi menu
    readonly property color dim: "#73ebdbb2"
    readonly property color line: "#3c3836"
    readonly property string font: "JetBrainsMonoNL Nerd Font"
    readonly property int fontSize: 11

    // bar
    readonly property color barBg: "#171717"
    readonly property color urgent: "#cc241d"
    readonly property color hover: "#40d65d0e"
    readonly property string barFont: "JetBrainsMonoNL NFP"
    readonly property int barFontSize: 10
    readonly property int barHeight: 24
}
