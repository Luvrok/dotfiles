import QtQuick
import Quickshell
import Quickshell.Io
import qs

// rofi-librewolf: pick a profile from ~/.librewolf/profiles.ini
Menu {
    id: menu

    input: false
    menuWidth: ch(24)
    padV: 20
    padH: 0
    align: Text.AlignHCenter

    onAccepted: (index, text) => {
        hide();
        Quickshell.execDetached(["librewolf", "--no-remote", "-P", text]);
        done();
    }

    FileView {
        id: ini
        path: Quickshell.env("HOME") + "/.librewolf/profiles.ini"
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        // the Name= of every [Profile*] section
        const profiles = [];
        let inProfile = false;
        for (const line of ini.text().split("\n")) {
            if (line.startsWith("["))
                inProfile = line.startsWith("[Profile");
            else if (inProfile && line.startsWith("Name=")) {
                profiles.push(line.slice(5));
                inProfile = false;
            }
        }
        if (profiles.length === 0) {
            done();
            return;
        }
        lines = profiles.length;
        show(profiles);
    }
}
