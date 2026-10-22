import QtQuick
import Quickshell
import Quickshell.Io
import qs

// a calculator on qalc (libqalculate): the answer shows as you type,
// units and currencies too (100 usd to eur, 5 ft to cm, 2^64). enter
// copies it and keeps it in the list below, enter on a line there copies
// that one. qalc runs with the C locale, a dot is the decimal point
Menu {
    id: menu

    property string answer: ""
    // "expression = answer", this session's
    property var history: []

    function ask(text) {
        if (text.trim() === "") {
            answer = "";
            return;
        }
        qalc.exec(["qalc", "-t", text]);
    }

    function copy(text) {
        Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", text]);
    }

    title: "calc"
    icon: "\u{f00ec}"
    status: answer !== "" ? `= ${answer}` : ""
    statusAccent: answer !== ""
    prompt: "2 + 2, 100 usd to eur"
    input: true
    // the typed answer unless ↑↓ picked a line
    startOnFirst: false
    enterHint: "copy"
    lines: Math.max(1, Math.min(history.length, 8))
    empty: "nothing yet"
    menuWidth: ch(64)

    onTextChanged: debounce.restart()

    onAccepted: (index, text) => {
        // a line from before
        if (index >= 0) {
            const line = history[index];
            copy(line.slice(line.lastIndexOf("= ") + 2));
            hide();
            done();
            return;
        }
        if (answer === "")
            return;
        copy(answer);
        history = [`${text} = ${answer}`, ...history];
        answer = "";
        show(history);
    }

    Timer {
        id: debounce
        interval: 120
        onTriggered: menu.ask(menu.text)
    }

    Process {
        id: qalc
        environment: ({
                LC_ALL: "C"
            })
        stdout: StdioCollector {
            onStreamFinished: menu.answer = text.trim().split("\n").pop() ?? ""
        }
    }

    Component.onCompleted: show([])
}
