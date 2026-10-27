# radarr, sonarr and qbittorrent for the add-on: their apis with the keys
# arr-keys made (../../arr), the dialogs around them. arr.json, its ports
# and paths, is ../../arr/shared.nix (../addons.nix)
import json
import os
import threading
import urllib.error
import urllib.parse
import urllib.request

import xbmc
import xbmcgui

HERE = os.path.dirname(os.path.abspath(__file__))
with open(os.path.join(HERE, "arr.json")) as f:
    C = json.load(f)
NAME = "Movie pipe"
# arr/setup.py's
PROFILE = "BDRip 1080p"
# 127.0.0.1, never through kodi's proxy (../default.nix, useProxy)
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))


class Error(Exception):
    pass


def reason(raw):
    # servarr's errors: [{"errorMessage": ...}] or {"message": ...}
    try:
        body = json.loads(raw)
    except ValueError:
        return raw.decode(errors="replace")[:200]
    if isinstance(body, list):
        return "; ".join(e.get("errorMessage", "") for e in body)
    return body.get("message") or str(body)[:200]


class Api:
    def __init__(self, app):
        self.app = app
        self.base = f"http://127.0.0.1:{C[app]}/api/v3"

    def call(self, method, path, body=None, timeout=60, **query):
        try:
            with open(f"{C['keys']}/{self.app}") as f:
                key = f.read().strip()
        except OSError:
            raise Error(f"{self.app}: нет ключа в {C['keys']}")
        url = self.base + path + ("?" + urllib.parse.urlencode(query) if query else "")
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data, {"X-Api-Key": key, "Content-Type": "application/json"}, method=method)
        try:
            with OPENER.open(req, timeout=timeout) as r:
                raw = r.read()
        except urllib.error.HTTPError as e:
            raise Error(f"{self.app}: {reason(e.read())}")
        except OSError:
            raise Error(f"{self.app} не отвечает")
        return json.loads(raw) if raw.strip() else None

    def get(self, path, timeout=60, **query):
        return self.call("GET", path, None, timeout, **query)

    def post(self, path, body, timeout=60):
        return self.call("POST", path, body, timeout)

    def put(self, path, body):
        return self.call("PUT", path, body)

    def delete(self, path, **query):
        return self.call("DELETE", path, **query)

    def command(self, name, **args):
        return self.post("/command", dict(args, name=name))

    def new(self):
        # what a film or a show added here gets: setup.py's profile, the
        # library's folder
        profiles = self.get("/qualityprofile")
        profile = next((p for p in profiles if p["name"] == PROFILE), profiles[0])
        return {"qualityProfileId": profile["id"], "rootFolderPath": C["library"][self.app]}


def notify(title, text, time=5000):
    xbmcgui.Dialog().notification(title, text, xbmcgui.NOTIFICATION_INFO, time)


def error(e):
    xbmcgui.Dialog().notification(NAME, str(e), xbmcgui.NOTIFICATION_ERROR, 8000)


def waiting(title, text, work):
    # work() in a thread under a progress dialog; None when cancelled
    out = {}

    def run():
        try:
            out["value"] = work()
        except Exception as e:
            out["error"] = e

    t = threading.Thread(target=run, daemon=True)
    t.start()
    progress = xbmcgui.DialogProgress()
    progress.create(title, text)
    seconds = 0
    while t.is_alive():
        if progress.iscanceled():
            progress.close()
            return None
        xbmc.sleep(250)
        seconds += 0.25
        progress.update(min(99, int(seconds)), f"{text} {int(seconds)} с")
    progress.close()
    if "error" in out:
        raise out["error"]
    return out["value"]


def gb(size):
    return f"{size / 1024 ** 3:.1f} ГБ"


def qbittorrent(path, **query):
    # its web ui on 127.0.0.1, no login from this machine
    url = f"http://127.0.0.1:{C['qbittorrent']}/api/v2{path}?" + urllib.parse.urlencode(query)
    try:
        with OPENER.open(url, timeout=5) as r:
            return json.loads(r.read())
    except (OSError, ValueError):
        raise Error("qbittorrent не отвечает")
