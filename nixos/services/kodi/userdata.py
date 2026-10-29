# kodi's userdata after a switch, before kodi reads it:
#   userdata.py enable DATADIR ID...       the add-ons kodi installed
#                                          switched off, on
#   userdata.py defaults DATADIR FILE.json its first settings and files
# kodi turns on an add-on it didn't install itself only by hand, and writes
# guisettings.xml when it quits, over ours: with kodi on, the next switch
# does that part. its add-on database is kodi's while it runs too, a full
# database (it's busy) is a warning, not a failed switch
import glob
import json
import os
import sqlite3
import sys
import xml.etree.ElementTree as ET

what, datadir = sys.argv[1], sys.argv[2]


def running():
    for pid in filter(str.isdigit, os.listdir("/proc")):
        try:
            with open(f"/proc/{pid}/comm") as f:
                if f.read().strip() == "kodi.bin":
                    return True
        except OSError:
            pass
    return False


def enable(ids):
    # no database yet (kodi never ran): nothing, the next switch does it
    found = glob.glob(os.path.join(datadir, "userdata/Database/Addons*.db"))

    def number(path):
        return int(os.path.basename(path)[len("Addons") : -len(".db")])

    db = max(found, key=number, default=None)
    if db is None:
        return
    try:
        with sqlite3.connect(db, timeout=10) as c:
            for addon in ids:
                c.execute(
                    "insert into installed (addonID, enabled, installDate)"
                    " values (?, 1, datetime('now'))"
                    " on conflict (addonID) do update set enabled = 1",
                    (addon,),
                )
    except sqlite3.Error as e:
        print(f"userdata: {db}: {e}", file=sys.stderr)


def settings(spec):
    path = os.path.join(datadir, "userdata/guisettings.xml")
    try:
        tree = ET.parse(path)
    except FileNotFoundError:
        tree = ET.ElementTree(ET.Element("settings", version="2"))
    root = tree.getroot()
    have = {s.get("id"): s for s in root.iter("setting")}
    changed = False
    for name, value in spec["settings"].items():
        s = have.get(name)
        if s is None:
            s = ET.SubElement(root, "setting", id=name)
        elif s.get("default") != "true":
            continue
        s.attrib.pop("default", None)
        s.text = value
        changed = True
    if changed:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tree.write(path + ".part", encoding="utf-8", xml_declaration=True)
        os.replace(path + ".part", path)


def files(spec):
    for name, text in spec["files"].items():
        path = os.path.join(datadir, name)
        if not os.path.exists(path):
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as f:
                f.write(text)


def defaults(path):
    with open(path) as f:
        found = json.load(f)
    files(found)
    if not running():
        settings(found)


if what == "enable":
    enable(sys.argv[3:])
elif what == "defaults":
    defaults(sys.argv[3])
else:
    sys.exit(f"userdata: {what}: enable or defaults")
