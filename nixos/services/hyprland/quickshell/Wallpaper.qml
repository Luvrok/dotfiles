import QtQuick
import Quickshell
import Quickshell.Wayland

// sway's `output * bg <file> fill #171717`: no file, plain background
PanelWindow {
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.barBg
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "wallpaper"

    Image {
        anchors.fill: parent
        source: "file://" + Quickshell.env("HOME") + "/HOME/wizzard/wallpaper/art/nature/Church_Heart_of_the_Andes.jpg"
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(width, height)
        asynchronous: true
    }
}
