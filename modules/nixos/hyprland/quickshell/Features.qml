pragma Singleton

import QtQuick

// what the host has switched on. the file here is the default (for
// `qs -p` from the repo), the system build writes the real one
// (modules/nixos/hyprland/default.nix) from the host's config
QtObject {
    // services.jarvis.enable: its menu, its bar icon and its key
    readonly property bool jarvis: true
}
