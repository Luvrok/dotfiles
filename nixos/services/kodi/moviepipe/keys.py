# a letter pressed in the add-on's windows (onAction). kodi's button code
# of a key is 0xF000 + its virtual key (A..Z, upper case ascii), ctrl, shift,
# alt and a long press above that; it's never the character (ord("r") never
# matched). a ru layout gives the us keys (../kodi-keys.patch).
# ../keyboard.xml has them as noop, so they come here and do nothing else
VKEY = 0xF000
SHIFT = 0x20000
LONG = 0x1000000


def letter(action):
    # "r", "R" with shift, None for anything else
    code = action.getButtonCode() & ~LONG
    key, mods = code & 0xFFFF, code & ~0xFFFF
    if key & 0xFF00 != VKEY or mods not in (0, SHIFT) or not ord("A") <= key & 0xFF <= ord("Z"):
        return None
    c = chr(key & 0xFF)
    return c if mods else c.lower()
