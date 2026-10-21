import QtQuick
import qs

// the text line of a menu, for a search or a prompt: a >, the text, a
// count on the right and a hairline under it that turns orange from the
// left while it has the keys. it folds away when it's closed
Item {
    id: field

    property bool open: true
    property string icon: ""
    property string placeholder: ""
    property string count: ""
    property bool password: false
    property font font
    readonly property alias input: input
    readonly property alias text: input.text

    signal edited
    signal pressed(var event)

    clip: true
    implicitHeight: open ? input.implicitHeight + 11 : 0
    opacity: open ? 1 : 0
    Behavior on implicitHeight {
        NumberAnimation {
            duration: 160
            easing.type: Easing.OutCubic
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: 160
        }
    }

    Item {
        x: 12
        y: 3
        width: field.width - 24
        height: input.implicitHeight

        Text {
            id: glyph
            anchors.verticalCenter: parent.verticalCenter
            text: field.icon
            color: input.activeFocus ? Theme.selBg : Theme.dim
            font.family: Theme.font
            font.pointSize: field.font.pointSize
            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }
        }

        Text {
            x: input.x
            width: input.width
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: field.placeholder
            textFormat: Text.PlainText
            elide: Text.ElideRight
            color: Theme.dim
            font: field.font
        }

        TextInput {
            id: input
            x: glyph.width + 8
            width: parent.width - x - (countText.text !== "" ? countText.width + 8 : 0)
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            color: Theme.fg
            selectionColor: Theme.selBg
            selectedTextColor: Theme.sel
            font: field.font
            echoMode: field.password ? TextInput.Password : TextInput.Normal
            passwordCharacter: "•"
            onTextEdited: field.edited()
            Keys.onPressed: e => field.pressed(e)
        }

        Text {
            id: countText
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: field.count
            color: Theme.dim
            font: field.font
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.line
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: input.activeFocus ? parent.width : 0
        height: 1
        color: Theme.selBg
        Behavior on width {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }
    }
}
