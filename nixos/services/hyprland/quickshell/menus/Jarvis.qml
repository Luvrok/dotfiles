import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.widgets

// jarvis, the voice assistant (nixos/services/jarvis): the daemon listens,
// the llm answers as the character, the tts speaks it. this menu talks to
// the daemon over its socket while it's open and starts listening when it
// opens. once the question is heard it slides away, the bar's mic
// (widgets/JarvisBar.qml) shows the rest and the answer comes as a
// notification, so the desktop is free while jarvis thinks and speaks.
// the big square is the mic, a click on it pauses. space pauses or
// resumes, c copies the answer, i picks the input, v the character (p
// plays its greeting), r listens again, u frees the vram. esc stops the
// voice and closes. no daemon: "jarvis is off"
Menu {
    id: menu

    readonly property string sockPath: `${Quickshell.env("XDG_RUNTIME_DIR")}/jarvis.sock`
    // the daemon's state, "off" while there's no daemon
    property string jarvis: "connecting"
    property real micLevel: 0
    property real ttsLevel: 0
    property var characters: []
    property string character: ""
    property var sources: []
    property string source: ""
    // the exchange on screen
    property string asked: ""
    property string answer: ""
    property string errorText: ""
    // main, input or voice
    property string page: "main"
    property string flash: ""

    readonly property var persona: characters.find(c => c.id === character) ?? null
    readonly property bool working: ["transcribing", "thinking", "searching", "voicing"].includes(jarvis)

    function send(msg) {
        if (!sock.connected)
            return;
        sock.write(JSON.stringify(msg) + "\n");
        sock.flush();
    }

    function received(line) {
        let m;
        try {
            m = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (m.type) {
        case "hello":
            jarvis = m.state;
            character = m.character;
            break;
        case "state":
            // the question is in: away, the rest goes on without the menu
            if (jarvis === "listening" && m.state === "transcribing" && page === "main")
                away.start();
            jarvis = m.state;
            if (m.state !== "error")
                errorText = "";
            break;
        case "level":
            if (m.src === "tts")
                ttsLevel = m.value;
            else
                micLevel = m.value;
            break;
        case "transcript":
            asked = m.text;
            answer = "";
            break;
        case "answer":
            if (m.text !== "")
                answer = m.text;
            if (m.last && m.question)
                asked = m.question;
            break;
        case "characters":
            characters = m.list;
            character = m.selected;
            if (page === "voice")
                listCharacters();
            break;
        case "sources":
            sources = m.list ?? [];
            source = m.selected;
            if (page === "input")
                listSources();
            break;
        case "error":
            errorText = m.message;
            break;
        }
    }

    function listSources() {
        active = [Math.max(0, sources.findIndex(s => s.id === source))];
        lines = Math.max(1, Math.min(sources.length, 10));
        show(sources.map(s => s.name), active[0]);
    }

    function listCharacters() {
        active = [Math.max(0, characters.findIndex(c => c.id === character))];
        lines = Math.max(1, Math.min(characters.length, 10));
        show(characters.map(c => `${c.name}\t${c.lang}`), active[0]);
    }

    function openPage(name) {
        page = name;
        if (name === "input")
            listSources();
        else
            listCharacters();
    }

    function home() {
        page = "main";
        active = [];
        lines = 0;
        show([]);
    }

    function copy() {
        if (answer === "")
            return;
        Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | wl-copy", "sh", answer]);
        flash = "copied";
        flashEnd.restart();
    }

    function togglePause() {
        send({
            type: jarvis === "paused" ? "resume" : "pause"
        });
    }

    title: persona?.name ?? "jarvis"
    icon: persona?.icon || "\u{f06a9}"
    status: flash !== "" ? flash : jarvis === "off" ? "jarvis is off" : page !== "main" ? page : working ? "" : jarvis
    statusAccent: flash !== "" || jarvis === "listening" || jarvis === "speaking" || jarvis === "error"
    // transcribing, thinking, searching and voicing pulse in the head, keys
    // still work
    activity: working ? jarvis : ""
    lines: 0
    menuWidth: ch(46)
    hints: page === "main" ? [["space", jarvis === "paused" ? "resume" : "pause"], ["c", "copy"], ["i", "input"], ["v", "voice"], ["r", "again"], ["u", "unload"], ["esc", "close"]] : [["j/k", "move"], ["enter", "pick"], ...(page === "voice" ? [["p", "preview"]] : []), ["h", "back"], ["esc", "close"]]
    body: page === "main" ? talk : null

    onAccepted: index => {
        if (page === "input" && sources[index])
            send({
                type: "set_source",
                id: sources[index].id
            });
        else if (page === "voice" && characters[index])
            send({
                type: "set_character",
                id: characters[index].id
            });
        home();
    }
    onBack: {
        if (page !== "main")
            home();
    }
    onCancelled: send({
        type: "close"
    })

    keys: e => {
        if (page === "voice" && key(e, "p")) {
            const c = characters[shown[rowsView.currentIndex]];
            if (c)
                send({
                    type: "preview_character",
                    id: c.id
                });
            return true;
        }
        if (page !== "main")
            return false;
        if (e.key === Qt.Key_Space)
            togglePause();
        else if (key(e, "c"))
            copy();
        else if (key(e, "i"))
            openPage("input");
        else if (key(e, "v"))
            openPage("voice");
        else if (key(e, "r"))
            send({
                type: "listen"
            });
        else if (key(e, "u")) {
            // the vram is free, nothing left to do here
            send({
                type: "unload"
            });
            flash = "unloaded";
            away.start();
        }
        else
            return key(e, "j") || key(e, "k") || e.key === Qt.Key_Return || e.key === Qt.Key_Enter;
        return true;
    }

    Socket {
        id: sock
        path: menu.sockPath
        connected: true
        parser: SplitParser {
            onRead: line => menu.received(line)
        }
        onConnectedChanged: {
            if (connected) {
                // the last answer to look at, then listen right away
                menu.send({
                    type: "last_answer"
                });
                menu.send({
                    type: "listen"
                });
            } else
                menu.jarvis = "off";
        }
        onError: menu.jarvis = "off"
    }

    // a moment to see "transcribing", then the layer rule slides it out
    Timer {
        id: away
        interval: 350
        onTriggered: {
            menu.hide();
            menu.done();
        }
    }

    Timer {
        id: flashEnd
        interval: 1200
        onTriggered: menu.flash = ""
    }

    Component {
        id: talk

        Column {
            id: talkBody

            width: parent?.width ?? 0
            topPadding: 8
            bottomPadding: 6
            spacing: 10

            MicTile {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 128
                height: 128
                mode: menu.jarvis === "off" || menu.jarvis === "connecting" ? "paused" : menu.jarvis
                micLevel: menu.micLevel
                ttsLevel: menu.ttsLevel
                font: menu.rowFont
                onClicked: menu.togglePause()
            }

            Grid {
                x: 12
                width: parent.width - 24
                columns: 2
                columnSpacing: 8
                rowSpacing: 4

                readonly property real label: menu.ch(8)

                Text {
                    visible: menu.asked !== ""
                    width: parent.label
                    text: "you"
                    color: Theme.dim
                    font: menu.rowFont
                }
                FadeText {
                    visible: menu.asked !== ""
                    width: parent.width - parent.label - 8
                    text: menu.asked
                    color: Theme.fg
                    font: menu.rowFont
                }

                Text {
                    visible: menu.answer !== ""
                    width: parent.label
                    text: menu.character
                    color: Theme.dim
                    font: menu.rowFont
                    elide: Text.ElideRight
                }
                FadeText {
                    visible: menu.answer !== ""
                    width: parent.width - parent.label - 8
                    text: menu.answer
                    color: Theme.fg
                    font: menu.rowFont
                }

                Text {
                    visible: menu.errorText !== "" || menu.jarvis === "off"
                    width: parent.label
                    text: "error"
                    color: Theme.urgent
                    font: menu.rowFont
                }
                FadeText {
                    visible: menu.errorText !== "" || menu.jarvis === "off"
                    width: parent.width - parent.label - 8
                    text: menu.jarvis === "off" ? "no daemon on the socket: systemctl --user status jarvis" : menu.errorText
                    color: Theme.urgent
                    font: menu.rowFont
                }
            }
        }
    }

    // selectable text that fades in when it changes, like the key hints
    component FadeText: TextEdit {
        id: fade
        readOnly: true
        selectByMouse: true
        textFormat: TextEdit.PlainText
        wrapMode: TextEdit.Wrap
        selectionColor: Theme.selBg
        selectedTextColor: Theme.sel
        onTextChanged: fadeIn.restart()

        NumberAnimation {
            id: fadeIn
            target: fade
            property: "opacity"
            from: 0
            to: 1
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    // closing it some other way (the hotkey again) leaves the request
    // running: only esc stops it
    Component.onCompleted: show([])
}
