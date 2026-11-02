import QtQuick
import Quickshell
import Quickshell.Io
import qs

// clipboard history, like sway-clip. hyprland.lua runs
// `wl-paste --watch cliphist store`, that fills it. esc keeps the clipboard.
// a picture under the cursor shows above the text line: cliphist decodes
// it once into $XDG_RUNTIME_DIR/hypr-clip
Menu {
    id: menu

    // cliphist lines, "id<tab>preview"
    property var entries: []
    readonly property string cache: `${Quickshell.env("XDG_RUNTIME_DIR")}/hypr-clip`
    // the picture shown, a file url or ""
    property string picture: ""
    // decoded ones, by cliphist id
    property var decoded: ({})

    // cliphist's preview of a picture: [[ binary data 33 KiB png 1920x1080 ]]
    function imageType(entry) {
        const m = entry.match(/\t\[\[ binary data .* (png|jpe?g|gif|webp|bmp) /i);
        return m ? m[1].toLowerCase() : "";
    }

    function preview() {
        const entry = current >= 0 ? entries[current] : "";
        const type = entry ? imageType(entry) : "";
        if (type === "") {
            picture = "";
            return;
        }
        const id = entry.slice(0, entry.indexOf("\t"));
        const file = `${cache}/${id}.${type}`;
        if (decoded[id]) {
            picture = `file://${file}`;
            return;
        }
        picture = "";
        decoder.entryId = id;
        decoder.file = file;
        decoder.exec(["sh", "-c", 'mkdir -p "$(dirname "$2")" && printf "%s\\n" "$1" | cliphist decode > "$2"', "sh", entry, file]);
    }

    onCurrentChanged: preview()

    title: "clipboard"
    icon: "\u{f014c}"
    prompt: "search"
    input: true
    searchable: true
    enterHint: "copy"
    lines: 15

    onAccepted: (index, text) => {
        hide();
        if (index >= 0)
            Quickshell.execDetached(["sh", "-c", "printf '%s\\n' \"$1\" | cliphist decode | wl-copy", "sh", entries[index]]);
        done();
    }

    body: Component {
        Item {
            width: parent?.width ?? 0
            implicitHeight: menu.picture !== "" ? 200 : 0
            clip: true
            Behavior on implicitHeight {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Image {
                anchors.fill: parent
                anchors.margins: 8
                source: menu.picture
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: false
            }
        }
    }

    Process {
        id: decoder

        property string entryId
        property string file

        onExited: code => {
            if (code !== 0)
                return;
            menu.decoded[entryId] = true;
            menu.preview();
        }
    }

    Process {
        running: true
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                menu.entries = text.split("\n").filter(l => l !== "");
                // no taller than the history
                menu.lines = Math.max(1, Math.min(menu.entries.length, 15));
                // the preview only, like -display-columns 2. a tab would
                // make a column
                menu.show(menu.entries.map(l => l.slice(l.indexOf("\t") + 1).replace(/\t/g, " ")));
            }
        }
    }
}
