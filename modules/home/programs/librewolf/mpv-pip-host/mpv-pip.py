#!/usr/bin/env python3
import json
import os
import socket
import struct
import subprocess
import sys


def get_message():
    raw = sys.stdin.buffer.read(4)
    if len(raw) < 4:
        sys.exit(0)
    (length,) = struct.unpack("=I", raw)
    data = b""
    while len(data) < length:
        chunk = sys.stdin.buffer.read(length - len(data))
        if not chunk:
            sys.exit(0)
        data += chunk
    return json.loads(data)


def send_message(content):
    data = json.dumps(content).encode("utf-8")
    sys.stdout.buffer.write(struct.pack("=I", len(data)))
    sys.stdout.buffer.write(data)
    sys.stdout.buffer.flush()


def main():
    url = get_message().get("url", "")
    if not isinstance(url, str) or not url.startswith(("http://", "https://")):
        send_message({"ok": False})
        return

    runtime = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    sock = os.path.join(runtime, "mpv-pip.sock")

    # one pip window: another video replaces the one playing in it
    if os.path.exists(sock):
        try:
            client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            client.connect(sock)
            client.sendall((json.dumps({"command": ["loadfile", url, "replace"]}) + "\n").encode())
            client.close()
            send_message({"ok": True})
            return
        except OSError:
            try:
                os.unlink(sock)
            except OSError:
                pass

    # mpv.conf starts fullscreen (fs=yes), this one does not. the window
    # rule for class mpv-pip floats it in the corner, 10 px from the edges
    try:
        subprocess.Popen(
            [
                "mpv",
                "--fs=no",
                "--keep-open=no",
                "--wayland-app-id=mpv-pip",
                "--x11-name=mpv-pip",
                "--input-ipc-server=" + sock,
                "--ytdl-raw-options=no-playlist=",
                "--",
                url,
            ],
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
    except OSError:
        send_message({"ok": False})
        return
    send_message({"ok": True})


if __name__ == "__main__":
    main()
