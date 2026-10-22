import QtQuick
import Quickshell
import qs

// nixos_menu: sapply, supdate, sclean and their remote twins. a command
// is typed into the mini kitty scratchpad (scripts/nixrun, special:spnix,
// $mod+ctrl+u), it shows, the build and a sudo password happen there.
// hide it with $mod+ctrl+u while it builds, sapply's notification says
// how it went. t shows or hides it without a command
Menu {
    id: menu

    // the hosts the remote rows deploy to, by their flake and ssh name
    readonly property var hosts: ["jedha", "mos-eisley", "kessel"]

    // [row, command line], "" a divider
    readonly property var commands: [
        ["apply\tnh os switch", "sapply"],
        ["update\tflake update, switch", "supdate"],
        ["clean\tgc, optimise", "sclean"],
        ["", ""],
        ...hosts.map(h => [`apply ${h}\tremote switch`, `sapply-remote ${h} ${h}`]),
        ...hosts.map(h => [`clean ${h}\tremote gc`, `sclean-remote ${h}`])
    ]

    function toggle() {
        hide();
        Hypr.dispatchLater(`hl.dsp.workspace.toggle_special("spnix")`);
        done();
    }

    title: "nixos"
    icon: "\u{f313}"
    input: false
    enterHint: "run"
    actions: [["t", "terminal"]]
    lines: commands.length
    menuWidth: ch(48)

    keys: e => {
        if (!key(e, "t"))
            return false;
        toggle();
        return true;
    }

    onAccepted: index => {
        const c = commands[index];
        if (!c || c[1] === "")
            return;
        hide();
        Quickshell.execDetached(["bash", Quickshell.shellPath("scripts/nixrun"), c[1]]);
        done();
    }

    Component.onCompleted: show(commands.map(c => c[0]))
}
