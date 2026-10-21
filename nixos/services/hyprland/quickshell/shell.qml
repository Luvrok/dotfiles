import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.menus

// the hyprland shell: wallpaper and bar on every monitor, and menus for what
// the rofi scripts do in i3 and sway. hyprland.lua starts it and calls
//   qs -c hyprland ipc call menu open <name>
//   qs -c hyprland ipc call bar toggle
//   qs -c hyprland ipc call record stop
// hypr-askpass calls `askpass ask <prompt>`, hypr-pinentry
// `askpass query <kind> <prompt> <desc> <error>`, both wait for `answered`
ShellRoot {
    id: shell

    property bool barShown: true
    // the open menu, it shows on the monitor that had focus
    property string menu: ""
    property ShellScreen menuScreen: null
    property ShellScreen askScreen: null
    // the password prompt, it opens over a menu that waits for it (pass
    // runs gpg, gpg asks)
    property bool asking: false
    property string askKind: "pin"
    property string askPrompt: ""
    property string askNote: ""
    property string askError: ""
    // the desktop entries are read in the background on first use, this
    // reads them at start, so run and kill have them when they open
    readonly property var apps: DesktopEntries.applications

    // the monitor that has focus
    function focusedScreen() {
        const focused = Hyprland.focusedMonitor?.name;
        for (let i = 0; i < Quickshell.screens.length; i++)
            if (Quickshell.screens[i].name === focused)
                return Quickshell.screens[i];
        return Quickshell.screens[0];
    }

    function open(name) {
        const same = menu === name;
        menu = "";
        if (same)
            return;
        menuScreen = focusedScreen();
        menu = name;
    }

    // later: a menu may give up while it's being created
    function close(name) {
        Qt.callLater(() => {
            if (menu === name)
                menu = "";
        });
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: perScreen
            required property ShellScreen modelData

            Wallpaper {
                screen: perScreen.modelData
            }
            Bar {
                screen: perScreen.modelData
                visible: shell.barShown
            }
        }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void {
            shell.barShown = !shell.barShown;
        }
    }

    // a second press closes the menu, like a key rofi grabbed
    IpcHandler {
        target: "menu"
        function open(name: string): void {
            shell.open(name);
        }
    }

    IpcHandler {
        target: "record"
        function stop(): void {
            Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/record"), "stop"]);
        }
    }

    IpcHandler {
        id: askpass
        target: "askpass"
        signal answered(text: string)
        function ask(prompt: string): void {
            query("pin", prompt, "", "");
        }
        // kind: pin, confirm or message
        function query(kind: string, prompt: string, desc: string, error: string): void {
            shell.askKind = kind;
            shell.askPrompt = prompt;
            shell.askNote = desc;
            shell.askError = error;
            shell.askScreen = shell.focusedScreen();
            shell.asking = true;
        }
    }

    LazyLoader {
        active: shell.menu === "run"
        Run {
            screen: shell.menuScreen
            onDone: shell.close("run")
        }
    }
    LazyLoader {
        active: shell.menu === "clip"
        Clip {
            screen: shell.menuScreen
            onDone: shell.close("clip")
        }
    }
    LazyLoader {
        active: shell.menu === "librewolf"
        Librewolf {
            screen: shell.menuScreen
            onDone: shell.close("librewolf")
        }
    }
    LazyLoader {
        active: shell.menu === "power"
        Power {
            screen: shell.menuScreen
            onDone: shell.close("power")
        }
    }
    LazyLoader {
        active: shell.menu === "bluetooth"
        Bluetooth {
            screen: shell.menuScreen
            onDone: shell.close("bluetooth")
        }
    }
    LazyLoader {
        active: shell.menu === "pass"
        Pass {
            screen: shell.menuScreen
            onDone: shell.close("pass")
        }
    }
    LazyLoader {
        active: shell.menu === "kill"
        Kill {
            screen: shell.menuScreen
            onDone: shell.close("kill")
        }
    }
    LazyLoader {
        active: shell.menu === "audio"
        Audio {
            screen: shell.menuScreen
            onDone: shell.close("audio")
        }
    }
    LazyLoader {
        active: shell.menu === "translate"
        Translate {
            screen: shell.menuScreen
            onDone: shell.close("translate")
        }
    }
    LazyLoader {
        active: shell.menu === "wifi"
        Wifi {
            screen: shell.menuScreen
            onDone: shell.close("wifi")
        }
    }
    LazyLoader {
        active: shell.menu === "record"
        Record {
            screen: shell.menuScreen
            onDone: shell.close("record")
        }
    }
    LazyLoader {
        active: shell.asking
        Askpass {
            screen: shell.askScreen
            kind: shell.askKind
            prompt: shell.askPrompt
            note: shell.askNote
            error: shell.askError
            onAnswered: text => askpass.answered(text)
            onDone: Qt.callLater(() => shell.asking = false)
        }
    }
}
