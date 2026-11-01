import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.widgets

// the screenshot, like flameshot: grim took the monitor the moment the key
// went down (shell.qml), this shows that frame frozen over everything.
// drag to select, then draw in it: r rect, a arrow, l line, p pen, m marker,
// t text, b blur (a mosaic), v selects again, f takes the whole screen.
// c the color of what's drawn next, [ ] thinner and thicker, u or ctrl+z
// undo. enter copies it, s saves it to flameshot's folder and copies
// the path, shift+s asks where (the file chooser portal, hypr-savefile),
// esc drops it
PanelWindow {
    id: shot

    // the frame grim wrote
    property string frame: ""
    signal done

    readonly property var colors: [Theme.selBg, Theme.urgent, "#98971a", "#458588", Theme.sel, "#171717"]
    property int colorAt: 0
    // the drawing color (the window has a color of its own)
    readonly property color ink: colors[colorAt]
    property int lineWidth: 3
    property string tool: "select"
    // x, y, w, h of the selection, w 0 for none yet
    property rect sel: Qt.rect(0, 0, 0, 0)
    // {tool, color, width, pts: [{x, y}], text}
    property var shapes: []
    property var drawing: null
    // the text being typed: {x, y}
    property var typing: null

    readonly property var tools: [
        { key: "v", tool: "select", icon: "\u{f0a6d}" },
        { key: "r", tool: "rect", icon: "\u{f05c6}" },
        { key: "a", tool: "arrow", icon: "\u{f005c}" },
        { key: "l", tool: "line", icon: "\u{f055e}" },
        { key: "p", tool: "pen", icon: "\u{f03eb}" },
        { key: "m", tool: "marker", icon: "\u{f0652}" },
        { key: "t", tool: "text", icon: "\u{f0284}" },
        { key: "b", tool: "blur", icon: "\u{f00b5}" }
    ]

    function norm(a, b) {
        return Qt.rect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(a.x - b.x), Math.abs(a.y - b.y));
    }

    function undo() {
        shapes = shapes.slice(0, -1);
        canvas.requestPaint();
    }

    function commitText() {
        if (typing && textInput.text !== "")
            shapes = [...shapes, {
                    tool: "text",
                    color: `${ink}`,
                    width: lineWidth,
                    pts: [{
                            x: typing.x,
                            y: typing.y
                        }],
                    text: textInput.text
                }];
        typing = null;
        textInput.text = "";
        keys.forceActiveFocus();
        canvas.requestPaint();
    }

    function stamp() {
        const d = new Date();
        const p = n => String(n).padStart(2, "0");
        return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}_${p(d.getHours())}-${p(d.getMinutes())}-${p(d.getSeconds())}`;
    }

    // the selection as a png: copied ("copy"), saved and its path copied
    // ("save"), or saved where the file chooser says ("ask")
    function finish(how) {
        if (sel.width < 2 || sel.height < 2)
            return;
        commitText();
        // the screenshots folder
        const shots = `${Quickshell.env("HOME")}/HOME/wizzard/media/screenshot`;
        const run = `${Quickshell.env("XDG_RUNTIME_DIR")}/hypr-shot`;
        const file = how === "save" ? `${shots}/${stamp()}.png` : how === "ask" ? `${run}/${stamp()}.png` : `${run}/shot.png`;
        Quickshell.execDetached(["mkdir", "-p", shots, run]);
        crop.grabToImage(r => {
            r.saveToFile(file);
            if (how === "save")
                Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy; notify-send -a screenshot "saved" "$1"', "sh", file]);
            else if (how === "ask")
                // the chooser opens once this layer is gone
                Quickshell.execDetached(["sh", "-c", 'to=$(hypr-savefile "$(basename "$1")" "$2" "save screenshot") && mv "$1" "$to" && printf %s "$to" | wl-copy && notify-send -a screenshot "saved" "$to"; rm -f "$1"', "sh", file, shots]);
            else
                Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"; notify-send -a screenshot "copied" "$2"', "sh", file, `${Math.round(sel.width)}×${Math.round(sel.height)}`]);
            shot.done();
        });
    }

    function handleKey(e) {
        e.accepted = true;
        const ctrl = Qt.ControlModifier;
        if (e.key === Qt.Key_Escape) {
            if (typing) {
                typing = null;
                textInput.text = "";
                keys.forceActiveFocus();
            } else
                done();
        } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || Kb.key(e, "c", ctrl))
            finish("copy");
        else if (Kb.key(e, "s") || Kb.key(e, "s", ctrl))
            // Kb.key doesn't look at shift
            finish(e.modifiers & Qt.ShiftModifier ? "ask" : "save");
        else if (Kb.key(e, "u") || Kb.key(e, "z", ctrl))
            undo();
        else if (Kb.key(e, "c"))
            colorAt = (colorAt + 1) % colors.length;
        else if (Kb.key(e, "["))
            lineWidth = Math.max(1, lineWidth - 1);
        else if (Kb.key(e, "]"))
            lineWidth = Math.min(12, lineWidth + 1);
        else if (Kb.key(e, "f")) {
            // like after a drag, the rect tool is next
            sel = Qt.rect(0, 0, width, height);
            tool = "rect";
        }
        else {
            const t = tools.find(t => Kb.key(e, t.key));
            if (t)
                tool = t.tool;
            else
                e.accepted = false;
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "black"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "shot"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Item {
        id: keys
        focus: true
        Keys.onPressed: e => shot.handleKey(e)
    }

    // the frame, dimmed outside the selection
    Image {
        id: background
        anchors.fill: parent
        source: shot.frame
        cache: true
    }
    Rectangle {
        anchors.fill: parent
        color: "#80000000"
    }

    // the selection, not dimmed, with what's drawn. grabbing it is the shot
    Item {
        id: crop
        x: shot.sel.x
        y: shot.sel.y
        width: shot.sel.width
        height: shot.sel.height
        clip: true

        Image {
            x: -crop.x
            y: -crop.y
            width: shot.width
            height: shot.height
            source: shot.frame
            cache: true
        }

        Canvas {
            id: canvas
            x: -crop.x
            y: -crop.y
            width: shot.width
            height: shot.height

            Component.onCompleted: loadImage(shot.frame)
            onImageLoaded: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                for (const s of [...shot.shapes, ...(shot.drawing ? [shot.drawing] : [])])
                    paintShape(ctx, s);
            }

            function paintShape(ctx, s) {
                const a = s.pts[0], b = s.pts[s.pts.length - 1];
                ctx.globalAlpha = 1;
                ctx.strokeStyle = s.color;
                ctx.fillStyle = s.color;
                ctx.lineWidth = s.width;
                if (s.tool === "rect")
                    ctx.strokeRect(Math.min(a.x, b.x), Math.min(a.y, b.y), Math.abs(a.x - b.x), Math.abs(a.y - b.y));
                else if (s.tool === "line" || s.tool === "arrow") {
                    ctx.beginPath();
                    ctx.moveTo(a.x, a.y);
                    ctx.lineTo(b.x, b.y);
                    if (s.tool === "arrow" && (a.x !== b.x || a.y !== b.y)) {
                        const ang = Math.atan2(b.y - a.y, b.x - a.x);
                        const len = 10 + s.width * 3;
                        for (const d of [-0.45, 0.45]) {
                            ctx.moveTo(b.x, b.y);
                            ctx.lineTo(b.x - len * Math.cos(ang + d), b.y - len * Math.sin(ang + d));
                        }
                    }
                    ctx.stroke();
                } else if (s.tool === "pen" || s.tool === "marker") {
                    if (s.tool === "marker") {
                        ctx.globalAlpha = 0.35;
                        ctx.lineWidth = s.width * 5;
                    }
                    ctx.beginPath();
                    ctx.moveTo(a.x, a.y);
                    for (const p of s.pts)
                        ctx.lineTo(p.x, p.y);
                    ctx.stroke();
                } else if (s.tool === "text") {
                    ctx.font = `bold ${10 + s.width * 3}px "JetBrainsMonoNL Nerd Font"`;
                    ctx.textBaseline = "top";
                    ctx.fillText(s.text, a.x, a.y);
                } else if (s.tool === "blur" && isImageLoaded(shot.frame)) {
                    // a mosaic: each cell is the frame's pixel in its middle
                    const r = shot.norm(a, b);
                    const cell = 12;
                    for (let y = r.y; y < r.y + r.height; y += cell)
                        for (let x = r.x; x < r.x + r.width; x += cell) {
                            const w = Math.min(cell, r.x + r.width - x), h = Math.min(cell, r.y + r.height - y);
                            ctx.drawImage(shot.frame, Math.floor(x + w / 2), Math.floor(y + h / 2), 1, 1, x, y, w, h);
                        }
                }
            }
        }

        // the text being typed, where it was clicked
        TextInput {
            id: textInput
            visible: shot.typing !== null
            x: (shot.typing?.x ?? 0) - crop.x
            y: (shot.typing?.y ?? 0) - crop.y
            color: shot.ink
            font.family: "JetBrainsMonoNL Nerd Font"
            font.bold: true
            font.pixelSize: 10 + shot.lineWidth * 3
            onAccepted: shot.commitText()
            Keys.onEscapePressed: shot.handleKey({ key: Qt.Key_Escape, accepted: false })
        }
    }

    // the selection's frame and size
    Rectangle {
        visible: shot.sel.width > 0
        x: shot.sel.x - 1
        y: shot.sel.y - 1
        width: shot.sel.width + 2
        height: shot.sel.height + 2
        color: "transparent"
        border.width: 1
        border.color: Theme.selBg

        Text {
            anchors.bottom: parent.top
            anchors.bottomMargin: 4
            x: 1
            text: `${Math.round(shot.sel.width)}×${Math.round(shot.sel.height)}`
            color: Theme.sel
            style: Text.Outline
            styleColor: "#171717"
            font.family: Theme.font
            font.pointSize: 9
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: shot.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
        property point start

        onPressed: e => {
            start = Qt.point(e.x, e.y);
            if (shot.typing)
                shot.commitText();
            const inside = e.x >= shot.sel.x && e.x <= shot.sel.x + shot.sel.width && e.y >= shot.sel.y && e.y <= shot.sel.y + shot.sel.height;
            if (shot.tool === "select" || !inside) {
                shot.tool = "select";
                shot.sel = Qt.rect(e.x, e.y, 0, 0);
            } else if (shot.tool === "text") {
                shot.typing = {
                    x: e.x,
                    y: e.y
                };
                textInput.forceActiveFocus();
            } else
                shot.drawing = {
                    tool: shot.tool,
                    color: `${shot.ink}`,
                    width: shot.lineWidth,
                    pts: [{
                            x: e.x,
                            y: e.y
                        }]
                };
        }
        onPositionChanged: e => {
            if (!pressed)
                return;
            if (shot.tool === "select")
                shot.sel = shot.norm(start, Qt.point(Math.max(0, Math.min(shot.width, e.x)), Math.max(0, Math.min(shot.height, e.y))));
            else if (shot.drawing) {
                const pts = shot.drawing.tool === "pen" || shot.drawing.tool === "marker" ? [...shot.drawing.pts, {
                        x: e.x,
                        y: e.y
                    }] : [shot.drawing.pts[0], {
                        x: e.x,
                        y: e.y
                    }];
                shot.drawing = Object.assign({}, shot.drawing, {
                    pts: pts
                });
                canvas.requestPaint();
            }
        }
        onReleased: {
            if (shot.drawing) {
                shot.shapes = [...shot.shapes, shot.drawing];
                shot.drawing = null;
                canvas.requestPaint();
            } else if (shot.tool === "select" && shot.sel.width > 4 && shot.sel.height > 4)
                // a selection is made, the rect tool is the next thing
                shot.tool = "rect";
        }
    }

    // the tools under the selection, above it when there's no room, inside
    // over the keys when there's none either (the whole screen)
    Row {
        id: bar
        visible: shot.sel.width > 4 && shot.sel.height > 4
        spacing: 4
        x: Math.max(4, Math.min(shot.width - width - 4, shot.sel.x))
        y: {
            const below = shot.sel.y + shot.sel.height + 8;
            const above = shot.sel.y - height - 24;
            return below + height < keysBox.y - 8 ? below : above >= 30 ? above : keysBox.y - height - 12;
        }

        Repeater {
            model: shot.tools

            delegate: Rectangle {
                required property var modelData
                width: 34
                height: 34
                color: shot.tool === modelData.tool ? Theme.selBg : Theme.bg
                border.width: 1
                border.color: Theme.border

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.icon
                    color: shot.tool === parent.modelData.tool ? Theme.sel : Theme.selBg
                    font.family: Theme.font
                    font.pointSize: 13
                }
                Text {
                    x: 3
                    y: 1
                    text: parent.modelData.key
                    color: shot.tool === parent.modelData.tool ? Theme.sel : Theme.dim
                    font.family: Theme.font
                    font.pointSize: 7
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: shot.tool = parent.modelData.tool
                }
            }
        }

        // the color, c changes it, and the width
        Rectangle {
            width: 34
            height: 34
            color: Theme.bg
            border.width: 1
            border.color: Theme.border

            Rectangle {
                anchors.centerIn: parent
                width: 8 + shot.lineWidth * 2
                height: width
                radius: width / 2
                color: shot.ink
            }
            MouseArea {
                anchors.fill: parent
                onClicked: shot.colorAt = (shot.colorAt + 1) % shot.colors.length
                onWheel: w => shot.lineWidth = Math.max(1, Math.min(12, shot.lineWidth + (w.angleDelta.y > 0 ? 1 : -1)))
            }
        }
    }

    // the keys, at the bottom of the screen
    Rectangle {
        id: keysBox
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 15
        width: hints.childrenRect.width + 24
        height: hints.childrenRect.height + 12
        color: Theme.bg
        border.width: 1
        border.color: Theme.border

        KeyHints {
            id: hints
            x: 12
            y: 6
            width: 900
            hints: shot.sel.width > 4 ? [["enter", "copy"], ["s", "save"], ["shift+s", "save as"], ["c", "color"], ["[ ]", "width"], ["u", "undo"], ["esc", "close"]] : [["drag", "select"], ["f", "whole screen"], ["esc", "close"]]
        }
    }
}
