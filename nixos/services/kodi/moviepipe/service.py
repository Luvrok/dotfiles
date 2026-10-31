# kodi's library takes in what radarr and sonarr bring: their history every
# minute, a folder they put in the library gets scanned (that folder only,
# once kodi isn't scanning: UpdateLibrary would stop a scan), a
# notification when a download starts, ends or fails. where it got to is
# in the add-on's data, what came while kodi was off is taken in at start.
# and majan's film page's cast row asked again while it's empty (Cast).
# tmdb's pictures through xray (./images.py)
import json
import os
import threading
import time
from datetime import datetime, timezone

import xbmc
import xbmcgui
import xbmcvfs

from arr import Api, Error, notify
from images import PORT, Images

STATE = xbmcvfs.translatePath("special://profile/addon_data/plugin.video.moviepipe/state.json")
POLL = 60
# how often the thread looks at the scan's list, and a request's patience:
# the history is small, a stuck one shouldn't hold the thread for a minute
TICK = 5
TIMEOUT = 20
INCLUDE = {
    "radarr": {"includeMovie": "true"},
    "sonarr": {"includeSeries": "true", "includeEpisode": "true"},
}


def parse(date):
    try:
        return datetime.fromisoformat(str(date).replace("Z", "+00:00"))
    except ValueError:
        return None


def now():
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def quality(record):
    return ((record.get("quality") or {}).get("quality") or {}).get("name", "")


def name(app, r):
    if app == "radarr" and "movie" in r:
        return f"{r['movie']['title']} ({r['movie']['year']})"
    if app == "sonarr" and "series" in r:
        return r["series"]["title"]
    return r["sourceTitle"]


def folder(app, record):
    # what the app put in the library, its root, not the download
    found = (record.get("movie") or record.get("series") or {}).get("path")
    return found or None


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
                records = Api(app).get("/history/since", timeout=TIMEOUT, date=since, **INCLUDE[app])
            except Error:
                continue
            # a record kodi can't read (no date) is not this one's business,
            # it used to stop the service for good
            dated = [(parse(r.get("date")), r) for r in records]
            dated = [(when, r) for when, r in dated if when and when > parse(since)]
            if not dated:
                continue
            # a season is a record per episode: a notification per download
            seen = set()
            for _, r in sorted(dated, key=lambda x: x[0]):
                event = r.get("eventType")
                key = (event, r.get("downloadId") or r.get("id"))
                if event == "downloadFolderImported":
                    found = folder(app, r)
                    if found and found not in self.state["scan"]:
                        self.state["scan"].append(found)
                if key in seen:
                    continue
                seen.add(key)
                if event == "grabbed":
                    notify("Downloading", f"{name(app, r)}, {quality(r)}")
                elif event == "downloadFolderImported":
                    notify("Downloaded", name(app, r))
                elif event == "downloadFailed":
                    notify("Download failed", name(app, r))
            self.state[app] = max(dated, key=lambda x: x[0])[1]["date"]
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


class Service(threading.Thread):
    # the requests go here, not in kodi's own thread for the script: kodi
    # waits for that one on quit, a dead radarr (its 60 s timeout) made it
    # wait too. a daemon thread is left behind instead
    def __init__(self, pipe):
        super().__init__(daemon=True)
        self.pipe = pipe
        self.monitor = xbmc.Monitor()

    def run(self):
        ticks = 0
        while not self.monitor.abortRequested():
            # the service is kodi's library and notifications: one bad
            # record, or one thing radarr says that this didn't expect,
            # must not end it for the rest of the session
            try:
                if ticks % POLL == 0:
                    self.pipe.poll()
                self.pipe.scan()
            except Exception as e:  # noqa: BLE001 - it runs till kodi quits
                xbmc.log(f"moviepipe: {e}", xbmc.LOGWARNING)
            ticks += TICK
            if self.monitor.waitForAbort(TICK):
                break


class Cast(threading.Thread):
    # majan's film page: the cast row is tmdb helper's (../majan-moviepipe.xml).
    # right after kodi starts tmdb helper isn't ready and the row stays empty
    # for good: still empty after WAIT s, its path again (the reload stamp),
    # TRIES times, then the row says so, r on the page tries again
    # (../keyboard.xml, default.py's reload)
    WAIT = 3
    TRIES = 3
    PAGE = "Window.IsActive(movieinformation) + !String.IsEqual(ListItem.DBType,set) + [!String.IsEmpty(ListItem.UniqueID(tmdb)) | !String.IsEmpty(ListItem.TVShowTitle)]"

    def __init__(self):
        super().__init__(daemon=True)
        self.monitor = xbmc.Monitor()
        self.home = xbmcgui.Window(10000)

    def run(self):
        page = stamp = None
        empty = tries = 0
        while not self.monitor.waitForAbort(0.5):
            if not xbmc.getCondVisibility(self.PAGE):
                page = None
                continue
            reload = self.home.getProperty("moviepipe.reload")
            now = (xbmc.getInfoLabel("ListItem.DBType"), xbmc.getInfoLabel("ListItem.UniqueID(tmdb)"), xbmc.getInfoLabel("ListItem.Label"))
            if now != page or (reload != stamp and tries >= self.TRIES):
                # another film, or r after it gave up: from the start
                page, empty, tries = now, 0, 0
                self.home.clearProperty("moviepipe.cast")
            stamp = reload
            if xbmc.getCondVisibility("Integer.IsGreater(Container(50).NumItems,0)"):
                empty = 0
                continue
            empty += 0.5
            if empty < self.WAIT or tries > self.TRIES:
                continue
            empty = 0
            tries += 1
            if tries > self.TRIES:
                self.home.setProperty("moviepipe.cast", "No cast on TMDb    r — again")
            else:
                stamp = str(time.time())
                self.home.setProperty("moviepipe.reload", stamp)


def log(message, bad):
    xbmc.log(f"moviepipe: {message}", xbmc.LOGWARNING if bad else xbmc.LOGINFO)


monitor = xbmc.Monitor()
Service(Pipe()).start()
Cast().start()
images = Images(log=log)
try:
    images.start()
except OSError as e:
    log(f"pictures on 127.0.0.1:{PORT}: {e}", True)
while not monitor.waitForAbort(TICK):
    pass
images.stop()
