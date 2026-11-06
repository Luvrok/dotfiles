import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// the still wallpaper: quickshell draws the picture on the background layer,
// one window per output, while Wall.photos is on. no process, no decoder.
// the pick is Wall.photoCurrent; WallMenu.qml switches the mode with s
Scope {
    id: root

    required property ShellScreen screen

    readonly property bool shown: Wall.photos && Wall.photoCurrent !== ""

    property real alpha: shown ? 1 : 0
    Behavior on alpha {
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }
    // stay alive while the fade out runs, then drop the surface
    readonly property bool alive: shown || alpha > 0.001

    readonly property string src: alive && Wall.photoCurrent !== "" ? fileUrl(Wall.photoCurrent) : ""
    // the picker already has this one in its cache: it covers the moment the
    // full picture needs to load
    readonly property string still: alive && Wall.photoCurrent !== "" ? fileUrl(Wall.thumb(Wall.photoCurrent)) : ""

    function fileUrl(path) {
        // spaces and cyrillic, and a # or ? in a name, are not url syntax
        return "file://" + path.split("/").map(s => encodeURIComponent(s)).join("/");
    }

    onShownChanged: if (shown) Wall.wantThumb(Wall.photoCurrent)

    PanelWindow {
        screen: root.screen
        visible: root.alive
        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "photo"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Item {
            anchors.fill: parent
            opacity: root.alpha

            Image {
                anchors.fill: parent
                source: root.still
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
            }

            Image {
                anchors.fill: parent
                source: root.src
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                // the still stays under it until the full picture is decoded
                opacity: status === Image.Ready ? 1 : 0
                Behavior on opacity {
                    NumberAnimation {
                        duration: 180
                        easing.type: Easing.OutQuad
                    }
                }
            }
        }
    }
}
