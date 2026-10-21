import QtQuick
import Quickshell
import Quickshell.Io
import qs.menus

// the hyprland shell: wallpaper and bar on every monitor, and menus for what
// the rofi scripts do in i3 and sway. hyprland.lua starts it and calls
//   qs -c hyprland ipc call menu open <name>
//   qs -c hyprland ipc call bar toggle
//   qs -c hyprland ipc call record stop
//   qs -c hyprland ipc call notifications close   (the popup, quiet, clear)
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

    // on the focused monitor, or on the one a bar was clicked on
    function open(name, screen) {
        const same = menu === name;
        menu = "";
        if (same)
            return;
        menuScreen = screen ?? Hypr.focusedScreen();
        menu = name;
    }

    // another menu on the same monitor, later: the one asking is unloaded
    function swap(name) {
        Qt.callLater(() => {
            menu = "";
            menu = name;
        });
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
                onOpenMenu: name => shell.open(name, perScreen.modelData)
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

    // the notification popup, Notifs is the server
    NotifyPopup {}

    IpcHandler {
        target: "notifications"
        // the popup goes, it stays in the menu
        function close(): void {
            Notifs.drop(Notifs.current);
        }
        function quiet(): void {
            Notifs.quiet = !Notifs.quiet;
        }
        function clear(): void {
            Notifs.clear();
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
            shell.askScreen = Hypr.focusedScreen();
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
            onGoTo: name => shell.swap(name)
        }
    }
    LazyLoader {
        active: shell.menu === "processes"
        Processes {
            screen: shell.menuScreen
            onDone: shell.close("processes")
            onGoTo: name => shell.swap(name)
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
        active: shell.menu === "system"
        System {
            screen: shell.menuScreen
            onDone: shell.close("system")
            onGoTo: name => shell.swap(name)
        }
    }
    LazyLoader {
        active: shell.menu === "calendar"
        Calendar {
            screen: shell.menuScreen
            onDone: shell.close("calendar")
        }
    }
    LazyLoader {
        active: shell.menu === "notifications"
        Notifications {
            screen: shell.menuScreen
            onDone: shell.close("notifications")
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
