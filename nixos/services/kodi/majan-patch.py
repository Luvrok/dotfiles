# what ../kodi/majan.nix asks this: copies ./majan-patches.nix's files into
# the skin, applies its patches, adds its "JetBrains Mono" fontset and
# draws its discs.
# majan-patch.py SKINDIR PATCHES.json FONTSDIR. a patch whose text isn't
# there as often as it says stops the build with its file and text: a skin
# update that rewrites one is then a build error, not a change in the wrong
# place. what's left is parsed as xml, a patch that cut a tag can't go in
import json
import os
import re
import shutil
import struct
import sys
import xml.etree.ElementTree as ET
import zlib

skin, spec, fonts = sys.argv[1], json.load(open(sys.argv[2])), sys.argv[3]
SIZE = re.compile(r"<size>([0-9]+)</size>")
FILE = re.compile(r"<filename>([^<]+)</filename>")
SPACING = re.compile(r"<linespacing>([0-9.]+)</linespacing>")


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


def line(path):
    # a font's line, in ems: what freetype (kodi) spaces its lines by, the
    # hhea table's ascender - descender + line gap over the head's units
    with open(path, "rb") as f:
        data = f.read()
    tables = {}
    for i in range(struct.unpack(">H", data[4:6])[0]):
        tag, _, offset, _ = struct.unpack(">4sIII", data[12 + 16 * i : 28 + 16 * i])
        tables[tag] = offset
    units = struct.unpack(">H", data[tables[b"head"] + 18 : tables[b"head"] + 20])[0]
    ascender, descender, gap = struct.unpack(">hhh", data[tables[b"hhea"] + 4 : tables[b"hhea"] + 10])
    return (ascender - descender + gap) / units


def fontset(font):
    # majan's "Default" set with jetbrains in place of its grotesk and
    # display fonts, 12% smaller: a monospace is wider. and spaced as
    # majan's own: its textboxes are as tall as so many of their lines
    # (the hub's plot 2, the spotlight's 3), with jetbrains' shorter lines
    # a third one showed cut in half
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
    for line_ in lines:
        was = FILE.search(line_)
        for family in font["families"]:
            line_ = line_.replace(family["from"], family["to"])
        size = SIZE.search(line_)
        if size and any(family["to"] in line_ for family in font["families"]):
            # as awk's int(n * scale + 0.5) did
            old = int(size.group(1))
            scaled = int(old * font["scale"] + 0.5)
            line_ = line_[: size.start()] + f"<size>{scaled}</size>" + line_[size.end() :]
            # the same line height: spacing * size * the font's line
            spacing = SPACING.search(line_)
            before = float(spacing.group(1)) if spacing else 1.0
            ratio = line(os.path.join(path, was.group(1))) * old / (line(os.path.join(path, FILE.search(line_).group(1))) * scaled)
            tag = f"<linespacing>{before * ratio:.3f}</linespacing>"
            line_ = line_[: spacing.start()] + tag + line_[spacing.end() :] if spacing else line_.replace("</font>", tag + "</font>")
        out.append(line_)
    # the "</fontset>" line's own indent came along
    while out and not out[-1].strip():
        out.pop()
    if "</fonts>" not in text:
        die(f"{name} has no </fonts>")
    text = text.replace("</fonts>", "\n".join(out) + "\n\t</fontset>\n</fonts>")
    write(xml, text)
    check(name)


def disc(name, size):
    # a white disc, a png of size px: an edge's pixel as white as the disc
    # covers of it (8x8 samples each). majan has no circle, the top bar's
    # focus is one (the skin colours it)
    n, r = 8, size / 2
    rows = b""
    for y in range(size):
        rows += b"\0"
        for x in range(size):
            covered = sum((x + (i + 0.5) / n - r) ** 2 + (y + (j + 0.5) / n - r) ** 2 <= r * r for i in range(n) for j in range(n))
            rows += bytes((255, 255, 255, round(255 * covered / n / n)))

    def chunk(tag, data):
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data))

    path = os.path.join(skin, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


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

for each in spec["disc"]:
    disc(each["to"], each["size"])

for name in sorted({p["file"] for p in spec["patch"]} | {c["to"] for c in spec["copy"]}):
    check(name)
