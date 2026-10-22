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
// hypr-dmenu calls `dmenu ask <rows file> <prompt> <row> <markup>` and waits
// for `answered`. hypr-askpass calls `askpass ask <prompt>`, hypr-pinentry
// `askpass query <kind> <prompt> <desc> <error>`, both wait for `answered`
ShellRoot {
    id: shell

    property bool barShown: true
    // the open menu, it shows on the monitor that had focus
    property string menu: ""
    property ShellScreen menuScreen: null
    // the menu the open one came from (tools), its q goes back there
    property string menuParent: ""
    property ShellScreen askScreen: null
    // the password prompt, it opens over a menu that waits for it (pass
    // runs gpg, gpg asks)
    property bool asking: false
    // a script's rofi -dmenu (hypr-dmenu): its rows file, prompt, row,
    // markup. its own loader too, a menu may be open
    property bool picking: false
    // the screenshot: grim's frame of the focused monitor, then Shot over it
    property bool shooting: false
    property string shotFrame: ""
    property ShellScreen shotScreen: null
    property var pick: ({})
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
        menuParent = "";
        menu = name;
    }

    // another menu on the same monitor, later: the one asking is unloaded.
    // parent: the menu its q goes back to
    function swap(name, parent) {
        Qt.callLater(() => {
            menu = "";
            menuParent = parent ?? "";
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

    // the lock screen: `lock now`
    Lock {
        id: lockScreen
    }

    IpcHandler {
        target: "lock"
        function now(): void {
            shell.menu = "";
            lockScreen.lock();
        }
    }

    Connections {
        target: Notifs
        function onReplyWanted() {
            shell.menu = "";
            shell.open("notifications");
        }
    }

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

    // print and tools s: the frame first, the menu shows it frozen
    IpcHandler {
        target: "shot"
        function take(): void {
            if (shell.shooting || grim.running)
                return;
            shell.menu = "";
            shell.shotScreen = Hypr.focusedScreen();
            shell.shotFrame = `${Quickshell.env("XDG_RUNTIME_DIR")}/hypr-shot/frame-${Date.now()}.png`;
            grim.exec(["sh", "-c", 'mkdir -p "$(dirname "$2")" && rm -f "$(dirname "$2")"/frame-*.png && grim -o "$1" "$2"', "sh", shell.shotScreen.name, shell.shotFrame]);
        }
    }

    Process {
        id: grim
        onExited: code => {
            if (code === 0)
                shell.shooting = true;
        }
    }

    IpcHandler {
        id: dmenu
        target: "dmenu"
        signal answered(index: string)
        function ask(file: string, prompt: string, selected: string, markup: string): void {
            shell.pick = {
                file: file,
                prompt: prompt,
                selected: parseInt(selected) || 0,
                markup: markup === "1",
                screen: Hypr.focusedScreen()
            };
            shell.picking = true;
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
        active: shell.menu === "tools"
        Tools {
            screen: shell.menuScreen
            onDone: shell.close("tools")
            onGoTo: name => shell.swap(name, "tools")
        }
    }
    LazyLoader {
        active: shell.menu === "emoji"
        Emoji {
            screen: shell.menuScreen
            parentMenu: shell.menuParent
            onDone: shell.close("emoji")
            onGoTo: name => shell.swap(name)
        }
    }
    LazyLoader {
        active: shell.menu === "calc"
        Calc {
            screen: shell.menuScreen
            parentMenu: shell.menuParent
            onDone: shell.close("calc")
            onGoTo: name => shell.swap(name)
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
        active: shell.menu === "player"
        Player {
            screen: shell.menuScreen
            parentMenu: shell.menuParent
            onDone: shell.close("player")
            onGoTo: name => shell.swap(name)
        }
    }
    LazyLoader {
        active: shell.menu === "units"
        Units {
            screen: shell.menuScreen
            parentMenu: shell.menuParent
            onDone: shell.close("units")
            onGoTo: name => shell.swap(name)
        }
    }
    LazyLoader {
        active: shell.menu === "switches"
        Switches {
            screen: shell.menuScreen
            parentMenu: shell.menuParent
            onDone: shell.close("switches")
            onGoTo: name => shell.swap(name)
        }
    }
    LazyLoader {
        active: shell.menu === "windows"
        Windows {
            screen: shell.menuScreen
            onDone: shell.close("windows")
        }
    }
    LazyLoader {
        active: shell.shooting
        Shot {
            screen: shell.shotScreen
            frame: `file://${shell.shotFrame}`
            onDone: Qt.callLater(() => shell.shooting = false)
        }
    }
    LazyLoader {
        active: shell.picking
        Dmenu {
            screen: shell.pick.screen
            file: shell.pick.file
            ask: shell.pick.prompt
            selected: shell.pick.selected
            markup: shell.pick.markup
            onAnswered: index => dmenu.answered(index)
            onDone: Qt.callLater(() => shell.picking = false)
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
