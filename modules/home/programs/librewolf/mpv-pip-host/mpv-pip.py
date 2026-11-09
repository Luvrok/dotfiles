#!/usr/bin/env python3
import hashlib
import json
import os
import re
import socket
import struct
import subprocess
import sys
import time
from urllib.parse import parse_qs, urlparse

# the window is 720x405 (hyprland.lua): 720p is enough and starts much
# faster than the 4K youtube hands mpv by default
FORMAT = "best[height<=720]/bestvideo[height<=720]+bestaudio/best"


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


def canonical(url):
    """the same youtube video has one url and one watch_later entry"""
    try:
        parsed = urlparse(url)
    except ValueError:
        return url
    host = (parsed.netloc or "").lower()
    video = None
    if host == "youtu.be" or host.endswith(".youtu.be"):
        video = parsed.path.strip("/").split("/")[0]
    elif host == "youtube.com" or host.endswith(".youtube.com") or host.endswith(".youtube-nocookie.com"):
        if parsed.path.rstrip("/") == "/watch":
            video = parse_qs(parsed.query).get("v", [None])[0]
        else:
            parts = [p for p in parsed.path.split("/") if p]
            if len(parts) > 1 and parts[0] in ("shorts", "embed", "live", "v"):
                video = parts[1]
    if video and re.fullmatch(r"[A-Za-z0-9_-]{6,}", video):
        return "https://www.youtube.com/watch?v=" + video
    return url


def url_start(url):
    """the t= or start= of a youtube link, in seconds"""
    try:
        parsed = urlparse(url)
    except ValueError:
        return 0.0
    if "youtube.com" not in parsed.netloc and "youtu.be" not in parsed.netloc:
        return 0.0
    query = parse_qs(parsed.query)
    value = query.get("t", query.get("start", [""]))[0]
    if value.isdigit():
        return float(value)
    match = re.fullmatch(r"(?:(\d+)h)?(?:(\d+)m)?(?:(\d+)s)?", value)
    if not match:
        return 0.0
    return float(int(match.group(1) or 0) * 3600 + int(match.group(2) or 0) * 60 + int(match.group(3) or 0))


def state_dir():
    state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    path = os.path.join(state, "mpv-pip")
    os.makedirs(path, mode=0o700, exist_ok=True)
    return path


def pip_position(name):
    """where the pip of this url stopped last time (mpv-pip.lua)"""
    try:
        with open(os.path.join(state_dir(), name), encoding="utf-8") as saved:
            return float(saved.read().strip())
    except (OSError, ValueError):
        return 0.0


def saved_position(url):
    """where mpv stopped this url last time, from its watch_later file"""
    state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    name = hashlib.md5(url.encode()).hexdigest().upper()
    for directory in (os.path.join(state, "mpv", "watch_later"), os.path.expanduser("~/.config/mpv/watch_later")):
        try:
            with open(os.path.join(directory, name), encoding="utf-8") as conf:
                for line in conf:
                    match = re.match(r"\s*start\s*=\s*([0-9.]+)\s*$", line)
                    if match:
                        return float(match.group(1))
        except OSError:
            pass
    return 0.0


def ipc(sock, command):
    client = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    client.settimeout(2)
    try:
        client.connect(sock)
        client.sendall((json.dumps({"command": command}) + "\n").encode())
        data = b""
        while b"\n" not in data:
            chunk = client.recv(65536)
            if not chunk:
                break
            data += chunk
        return json.loads(data.split(b"\n")[0]).get("data")
    finally:
        client.close()


def close_current(sock, url):
    """close the running pip: quit saves its position, and if it played
    this url its time is the newest one"""
    if not os.path.exists(sock):
        return 0.0
    position = 0.0
    try:
        path = ipc(sock, ["get_property", "path"])
        if isinstance(path, str) and canonical(path) == url:
            current = ipc(sock, ["get_property", "time-pos"])
            if isinstance(current, (int, float)):
                position = float(current)
    except (OSError, ValueError):
        pass
    try:
        ipc(sock, ["quit"])
    except (OSError, ValueError):
        pass
    for _ in range(40):
        if not os.path.exists(sock):
            break
        time.sleep(0.05)
    try:
        os.unlink(sock)
    except OSError:
        pass
    return position


def main():
    message = get_message()
    url = message.get("url", "")
    if not isinstance(url, str) or not url.startswith(("http://", "https://")):
        send_message({"ok": False})
        return

    video = canonical(url)
    runtime = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
    sock = os.path.join(runtime, "mpv-pip.sock")

    # close the running pip first: quit saves its position, and if it
    # played this url its time is the newest one
    old = close_current(sock, video)

    state = state_dir()
    name = hashlib.md5(video.encode()).hexdigest().upper()
    ours = pip_position(name)

    browser = message.get("start", 0)
    if not isinstance(browser, (int, float)):
        browser = 0.0

    # the tab's own time wins: it is where the user is right now. the
    # watch_later and the pip's own file are older spots of the same video,
    # so take the furthest (watched on in the pip, then opened again from a
    # tab that still sits at the old second)
    if message.get("live"):
        start = 0.0
    elif browser > 1:
        start = max(float(browser), saved_position(video), ours, old)
    elif url_start(url) > 0:
        start = url_start(url)
    elif ours > 1 or old > 1:
        start = max(ours, old, saved_position(video))
    else:
        # no time from anywhere: let mpv load its watch_later itself, with
        # the saved volume, speed and the rest
        start = 0.0

    lua = os.path.join(os.path.dirname(os.path.realpath(__file__)), "mpv-pip.lua")
    args = [
        "mpv",
        "--fs=no",
        "--keep-open=no",
        "--save-position-on-quit=yes",
        "--wayland-app-id=mpv-pip",
        "--x11-name=mpv-pip",
        "--input-ipc-server=" + sock,
        "--ytdl-format=" + FORMAT,
        "--ytdl-raw-options=no-playlist=",
        "--script=" + lua,
        "--script-opts=mpv-pip.dir=" + state + ",mpv-pip.name=" + name,
    ]
    if start > 1:
        args.append(f"--start={start:.3f}")
    args += ["--", video]

    try:
        subprocess.Popen(
            args,
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
