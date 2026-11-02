pragma Singleton

import QtQuick
import Quickshell

// keys by their us name on any layout: the Qt key or the xkb keycode of
// the us letter, so j/k/r... work on ru too. mods: the ctrl, alt and super
// it needs, shift doesn't matter. Menu and the screenshot use it
Singleton {
    // xkb keycodes of the us keys
    readonly property var codes: ({ "/": 61, "[": 34, "]": 35, a: 38, b: 56, c: 54, d: 40, e: 26, f: 41, g: 42, h: 43, i: 31, j: 44, k: 45, l: 46, m: 58, n: 57, o: 32, p: 33, q: 24, r: 27, s: 39, t: 28, u: 30, v: 55, w: 25, x: 53, y: 29, z: 52 })
    readonly property var named: ({ "/": Qt.Key_Slash, "[": Qt.Key_BracketLeft, "]": Qt.Key_BracketRight })

    function key(e, name, mods) {
        if ((e.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier)) !== (mods ?? Qt.NoModifier))
            return false;
        return e.key === (named[name] ?? Qt["Key_" + name.toUpperCase()]) || e.nativeScanCode === codes[name];
    }
}
