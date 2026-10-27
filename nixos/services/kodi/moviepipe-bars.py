# ./moviepipe's progress bars (windows.py): 0.png .. 100.png a 5% apart,
# white on a faint track for the skin's accent to colour.
# moviepipe-bars.py DIR
import struct
import sys
import zlib

WIDTH, HEIGHT = 200, 6


def chunk(kind, data):
    return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data))


for percent in range(0, 101, 5):
    filled = WIDTH * percent // 100
    line = b"\0" + b"".join(b"\xff\xff\xff" + (b"\xff" if x < filled else b"\x33") for x in range(WIDTH))
    with open(f"{sys.argv[1]}/{percent}.png", "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", zlib.compress(line * HEIGHT)))
        f.write(chunk(b"IEND", b""))
