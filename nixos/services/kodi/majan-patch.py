# what ../kodi/majan.nix asks this: copies ./majan-patches.nix's files into
# the skin, applies its patches and adds its "JetBrains Mono" fontset.
# majan-patch.py SKINDIR PATCHES.json FONTSDIR. a patch whose text isn't
# there as often as it says stops the build with its file and text: a skin
# update that rewrites one is then a build error, not a change in the wrong
# place. what's left is parsed as xml, a patch that cut a tag can't go in
import json
import os
import re
import shutil
import sys
import xml.etree.ElementTree as ET

skin, spec, fonts = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3]
SIZE = re.compile(r"<size>([0-9]+)</size>")


def die(message):
    sys.exit(f"majan: {message}")


def read(path):
    with open(path, encoding="utf-8") as f:
        return f.read()


def write(path, text):
    with open(path, "w", encoding="utf-8") as f:
        f.write(text)


def check(name):
    try:
        ET.parse(os.path.join(skin, name))
    except ET.ParseError as e:
        die(f"{name}: {e}")


def fontset(font):
    # majan's "Default" set with jetbrains in place of its grotesk and
    # display fonts, 12% smaller: a monospace is wider
    path = os.path.join(skin, "fonts")
    for name in font["files"]:
        shutil.copyfile(os.path.join(fonts, name), os.path.join(path, name))
    name = "1080i/Font.xml"
    xml = os.path.join(skin, name)
    text = read(xml)
    start = text.index('<fontset id="Default"')
    end = text.index("</fontset>", start)
    head, *lines = text[start:end].splitlines()
    out = [f'\t<fontset id="{font["set"]}" unicode="true">']
    for line in lines:
        for family in font["families"]:
            line = line.replace(family["from"], family["to"])
        if any(family["to"] in line for family in font["families"]):
            size = SIZE.search(line)
            if size:
                # as awk's int(n * scale + 0.5) did
                scaled = int(int(size.group(1)) * font["scale"] + 0.5)
                line = line[: size.start()] + f"<size>{scaled}</size>" + line[size.end() :]
        out.append(line)
    # the "</fontset>" line's own indent came along
    while out and not out[-1].strip():
        out.pop()
    if "</fonts>" not in text:
        die(f"{name} has no </fonts>")
    text = text.replace("</fonts>", "\n".join(out) + "\n\t</fontset>\n</fonts>")
    write(xml, text)
    check(name)


for copy in spec["copy"]:
    shutil.copyfile(copy["from"], os.path.join(skin, copy["to"]))

for patch in spec["patch"]:
    path = os.path.join(skin, patch["file"])
    text = read(path)
    # as many as the patch says, not one more (the skin has some of them in
    # a few places on purpose, "count") and not one less: either way the
    # skin moved them and this replacement lands in the wrong place
    found = text.count(patch["from"])
    want = patch.get("count", 1)
    if found != want:
        die(f"{patch['file']}: {found} of {patch['from']!r}, wanted {want}")
    write(path, text.replace(patch["from"], patch["to"]))

fontset(spec["font"])

for name in sorted({p["file"] for p in spec["patch"]} | {c["to"] for c in spec["copy"]}):
    check(name)
