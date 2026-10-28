# kodi's settings the first time, kodi's own after: a setting still at
# kodi's default gets ours (majan, its font), a file that isn't
# there yet gets written (iptv simple's channel lists). kodi writes
# guisettings.xml when it quits, over ours: with kodi on, the next switch
# does it. defaults.py DATADIR DEFAULTS.json
import json
import os
import sys
import xml.etree.ElementTree as ET

datadir = sys.argv[1]
with open(sys.argv[2]) as f:
    defaults = json.load(f)


def running():
    for pid in filter(str.isdigit, os.listdir("/proc")):
        try:
            with open(f"/proc/{pid}/comm") as f:
                if f.read().strip() == "kodi.bin":
                    return True
        except OSError:
            pass
    return False


def settings():
    path = os.path.join(datadir, "userdata/guisettings.xml")
    try:
        tree = ET.parse(path)
    except FileNotFoundError:
        tree = ET.ElementTree(ET.Element("settings", version="2"))
    root = tree.getroot()
    have = {s.get("id"): s for s in root.iter("setting")}
    changed = False
    for id, value in defaults["settings"].items():
        s = have.get(id)
        if s is None:
            s = ET.SubElement(root, "setting", id=id)
        elif s.get("default") != "true":
            continue
        s.attrib.pop("default", None)
        s.text = value
        changed = True
    if changed:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        tree.write(path + ".part", encoding="utf-8", xml_declaration=True)
        os.replace(path + ".part", path)


def files():
    for name, text in defaults["files"].items():
        path = os.path.join(datadir, name)
        if not os.path.exists(path):
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w") as f:
                f.write(text)


files()
if not running():
    settings()
