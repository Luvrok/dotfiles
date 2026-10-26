# sets kodi's gui settings in userdata/guisettings.xml: guisettings.py FILE
# id=value... kodi writes the file itself on exit, so it can't be a link
# like advancedsettings.xml. the rest of what's there stays. a missing file
# is enough with these alone, kodi fills in the defaults
import os
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
want = dict(arg.split("=", 1) for arg in sys.argv[2:])

if os.path.exists(path):
    tree = ET.parse(path)
else:
    tree = ET.ElementTree(ET.Element("settings", version="2"))
root = tree.getroot()

for setting in root.iter("setting"):
    value = want.pop(setting.get("id"), None)
    if value is not None:
        setting.text = value
        # default="true" is how kodi marks a value nobody changed
        setting.attrib.pop("default", None)
for id, value in want.items():
    ET.SubElement(root, "setting", id=id).text = value

os.makedirs(os.path.dirname(path), exist_ok=True)
tree.write(path, encoding="utf-8", xml_declaration=True)
