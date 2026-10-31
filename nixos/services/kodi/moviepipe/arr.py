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
            raise Error(f"{self.app}: no key in {C['keys']}")
        url = self.base + path + ("?" + urllib.parse.urlencode(query) if query else "")
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(url, data, {"X-Api-Key": key, "Content-Type": "application/json"}, method=method)
        try:
            with OPENER.open(req, timeout=timeout) as r:
                raw = r.read()
        except urllib.error.HTTPError as e:
            raise Error(f"{self.app}: {reason(e.read())}")
        except OSError as e:
            if isinstance(e, TimeoutError) or isinstance(getattr(e, "reason", None), TimeoutError):
                raise Error(f"{self.app} didn't answer in {timeout} s")
            raise Error(f"{self.app} doesn't answer")
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
    # work() in a thread, a bar in the corner meanwhile (kodi's background
    # progress): kodi stays usable, what comes next opens when it's done
    out = {}

    def run():
        try:
            out["value"] = work()
        except Exception as e:
            out["error"] = e

    t = threading.Thread(target=run, daemon=True)
    t.start()
    progress = xbmcgui.DialogProgressBG()
    progress.create(title, text)
    monitor = xbmc.Monitor()
    seconds = 0
    try:
        while t.is_alive():
            if monitor.waitForAbort(0.25):
                return None
            seconds += 0.25
            progress.update(min(99, int(seconds)), title, f"{text} {int(seconds)} s")
    finally:
        progress.close()
    if "error" in out:
        raise out["error"]
    return out["value"]


def gb(size):
    return f"{size / 1024 ** 3:.1f} GB"


def qbittorrent(path, form=None, **query):
    # its web ui on 127.0.0.1, no login from this machine. form: a POST
    url = f"http://127.0.0.1:{C['qbittorrent']}/api/v2{path}?" + urllib.parse.urlencode(query)
    data = urllib.parse.urlencode(form).encode() if form is not None else None
    try:
        with OPENER.open(urllib.request.Request(url, data), timeout=5) as r:
            raw = r.read()
    except urllib.error.HTTPError as e:
        raise Error(f"qbittorrent: {path}: {e.code}")
    except OSError:
        raise Error("qbittorrent doesn't answer")
    try:
        return json.loads(raw) if raw.strip() else None
    except ValueError:
        return raw.decode(errors="replace")
