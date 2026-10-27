# kodi's library takes in what radarr and sonarr bring: their history every
# minute, a folder they put in the library gets scanned (that folder only,
# once kodi isn't scanning: UpdateLibrary would stop a scan), a
# notification when a download starts, ends or fails. where it got to is
# in the add-on's data, what came while kodi was off is taken in at start
import json
import os
from datetime import datetime, timezone

import xbmc
import xbmcaddon
import xbmcvfs

from arr import Api, Error, notify

STATE = xbmcvfs.translatePath("special://profile/addon_data/plugin.video.moviepipe/state.json")
POLL = 60
INCLUDE = {
    "radarr": {"includeMovie": "true"},
    "sonarr": {"includeSeries": "true", "includeEpisode": "true"},
}


def parse(date):
    return datetime.fromisoformat(date.replace("Z", "+00:00"))


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def name(app, r):
    if app == "radarr" and "movie" in r:
        return f"{r['movie']['title']} ({r['movie']['year']})"
    if app == "sonarr" and "series" in r:
        return r["series"]["title"]
    return r["sourceTitle"]


class Pipe:
    def __init__(self):
        try:
            with open(STATE) as f:
                self.state = json.load(f)
        except (OSError, ValueError):
            self.state = {}
        for app in INCLUDE:
            self.state.setdefault(app, now())
        self.state.setdefault("scan", [])
        self.save()

    def save(self):
        os.makedirs(os.path.dirname(STATE), exist_ok=True)
        with open(STATE + ".part", "w") as f:
            json.dump(self.state, f)
        os.replace(STATE + ".part", STATE)

    def poll(self):
        for app in INCLUDE:
            since = self.state[app]
            try:
                records = Api(app).get("/history/since", date=since, **INCLUDE[app])
            except Error:
                continue
            records = [r for r in records if parse(r["date"]) > parse(since)]
            if not records:
                continue
            # a season is a record per episode: a notification per download
            seen = set()
            for r in sorted(records, key=lambda r: parse(r["date"])):
                event = r["eventType"]
                key = (event, r.get("downloadId") or r["id"])
                if event == "downloadFolderImported":
                    folder = r["movie"]["path"] if app == "radarr" else r["series"]["path"]
                    if folder not in self.state["scan"]:
                        self.state["scan"].append(folder)
                if key in seen:
                    continue
                seen.add(key)
                if event == "grabbed":
                    notify("Качаю", f"{name(app, r)}, {r['quality']['quality']['name']}")
                elif event == "downloadFolderImported":
                    notify("Скачано", name(app, r))
                elif event == "downloadFailed":
                    notify("Не скачалось", name(app, r))
            self.state[app] = max(records, key=lambda r: parse(r["date"]))["date"]
            self.save()

    def scan(self):
        if not self.state["scan"] or xbmc.getCondVisibility("Library.IsScanningVideo"):
            return
        folder = self.state["scan"].pop(0).rstrip("/") + "/"
        self.save()
        xbmc.executeJSONRPC(
            json.dumps(
                {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "VideoLibrary.Scan",
                    "params": {"directory": folder, "showdialogs": False},
                }
            )
        )


def players():
    # tmdb helper plays a second of its dummy.mp4 before a player that
    # isn't a file (ours, ../default.nix), and a file plays in mpv: only
    # its strm files get the dummy
    try:
        xbmcaddon.Addon("plugin.video.themoviedb.helper").setSettingBool("only_resolve_strm", True)
    except RuntimeError:
        pass


players()
monitor = xbmc.Monitor()
pipe = Pipe()
ticks = 0
while not monitor.abortRequested():
    if ticks % POLL == 0:
        pipe.poll()
    pipe.scan()
    ticks += 5
    if monitor.waitForAbort(5):
        break
