# ./moviepipe's progress bars (windows.py): 0.png .. 100.png a 5% apart,
# white on a faint track for the skin's accent to colour. and the person
# page's underline of the tab shown (person.py), 3 px at the bottom, 14 px
# in from the sides (its texture's border): ../moviepipe-underline.png
# moviepipe-bars.py DIR
import struct
import sys
import zlib

WIDTH, HEIGHT = 200, 6


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


def png(path, rows):
    # rows of rgba pixels
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", len(rows[0]) // 4, len(rows), 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(b"".join(b"\0" + row for row in rows))))
        f.write(chunk(b"IEND", b""))


for percent in range(0, 101, 5):
    filled = WIDTH * percent // 100
    line = b"".join(b"\xff\xff\xff" + (b"\xff" if x < filled else b"\x33") for x in range(WIDTH))
    png(f"{sys.argv[1]}/{percent}.png", [line] * HEIGHT)

clear, white = b"\0\0\0\0", b"\xff\xff\xff\xff"
png(
    f"{sys.argv[1]}/../moviepipe-underline.png",
    [clear * 32] * 5 + [clear * 14 + white * 4 + clear * 14] * 3,
)
