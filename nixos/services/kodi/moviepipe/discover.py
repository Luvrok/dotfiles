# 5, discover (resources/skins/Default/1080i/moviepipe-discover.xml): what
# tmdb has, trending, popular, in cinemas, upcoming, top rated, more like
# the library's newest, popular people, in rows of posters, films or shows
# (the chips). tmdb helper fills them (the rows' paths are the window's
# properties), so enter on a film is its player (Download…), i its page, c
# its menu; a show's enter is its page, a person's theirs (./person.py).
# what radarr and sonarr download is the first row, enter on it the
# downloads. the focused poster big at the top. a row gets its path only
# when the focus is two rows from it: tmdb helper asks tmdb for every
# poster's details the first time. SEARCH: the rows are what tmdb finds,
# back the rows again. t a trailer, r the rows again
import threading
import time
import urllib.parse

import xbmc
import xbmcgui

from actions import rpc
from arr import Error
from keys import letter
from trailer import trailer
from windows import downloads, show_downloads, window

HELPER = "plugin://plugin.video.themoviedb.helper/"
# (the row's name, tmdb helper's list, what's on it). the order here is the
# page's. {} in a name: the library's newest film or show
ROWS = {
    "movie": [
        ("Trending this week", "trending_week", "movie"),
        ("Popular", "popular", "movie"),
        ("In cinemas", "now_playing", "movie"),
        ("Upcoming", "upcoming", "movie"),
        ("Top rated", "top_rated", "movie"),
        ("Because you have {}", "recommendations", "movie"),
        ("Popular people", "popular", "person"),
    ],
    "tv": [
        ("Trending this week", "trending_week", "tv"),
        ("Popular", "popular", "tv"),
        ("On the air", "on_the_air", "tv"),
        ("Airing today", "airing_today", "tv"),
        ("Top rated", "top_rated", "tv"),
        ("Because you have {}", "recommendations", "tv"),
        ("Popular people", "popular", "person"),
    ],
    "search": [
        ("Films", "search", "movie"),
        ("TV shows", "search", "tv"),
        ("People", "search", "person"),
    ],
}
# the chips, row n's list is 200 + n: 201 the downloads, 202.. tmdb's
MOVIES, SHOWS, SEARCH, BROWSE = 101, 102, 103, 104
DOWNLOADS, FIRST, LAST = 201, 202, 208
# rows past the focus that get their path
AHEAD = 2
# s: how long a row may load before it counts as empty, how often the
# downloads row looks again
PATIENCE = 30
POLL = 10


def info(label):
    return xbmc.getInfoLabel(label)


def helper(**params):
    return f"{HELPER}?{urllib.parse.urlencode({k: v for k, v in params.items() if v})}"


def newest(kind):
    # the library's last added film or show: (title, tmdb id)
    method, key = ("VideoLibrary.GetMovies", "movies") if kind == "movie" else ("VideoLibrary.GetTVShows", "tvshows")
    try:
        found = rpc(method, properties=["title", "uniqueid"], sort={"method": "dateadded", "order": "descending"}, limits={"end": 10}).get(key) or []
    except Error:
        return None
    return next(((x["title"], x["uniqueid"]["tmdb"]) for x in found if (x.get("uniqueid") or {}).get("tmdb")), None)


def poster(app, records):
    # a download as a poster: radarr's film or sonarr's show
    q = records[0]
    what = q.get("movie") if app == "radarr" else q.get("series")
    what = what or {}
    art = next((i.get("remoteUrl") for i in what.get("images", []) if i.get("coverType") == "poster"), "")
    return what, art


class Discover(xbmcgui.WindowXML):
    def onInit(self):
        if getattr(self, "started", False):
            return
        self.started = True
        self.closing = False
        self.moved = False
        self.rows = []
        self.loads = 0
        self.stamp = ""
        self.query = ""
        self.mode = self.before = "movie"
        self.enabled = FIRST - 1
        self.keys = []
        self.posters = []
        self.show("movie")
        threading.Thread(target=self.poll, daemon=True).start()

    # the rows

    def show(self, mode):
        if mode != "search":
            self.before = mode
        self.mode = mode
        self.setProperty("mode", mode)
        self.setProperty("query", f"«{self.query}»" if mode == "search" else "")
        rows = []
        for title, kind, what in ROWS[mode]:
            extra = {}
            if kind == "recommendations":
                found = newest(what)
                if not found:
                    continue
                title = title.format(found[0])
                extra["tmdb_id"] = found[1]
            if kind == "search":
                extra["query"] = self.query
            rows.append((title, helper(info=kind, tmdb_type=what, **extra), what))
        self.rows = rows
        self.loads += 1
        threading.Thread(target=self.load, args=(self.loads,), daemon=True).start()

    def load(self, load):
        # the old rows away first: a new path keeps the old posters till the
        # new ones come. then the first rows, the rest as the focus nears
        for n in range(FIRST, LAST + 1):
            self.clear(n)
        self.enabled = FIRST - 1
        self.wait(lambda: not any(self.loaded(n) for n in range(FIRST, LAST + 1)), 2)
        if load != self.loads:
            return
        self.near(FIRST)
        # the focus on the first row once it's there, unless it moved
        if self.wait(lambda: self.loaded(FIRST) or load != self.loads) and not self.moved and load == self.loads:
            xbmc.executebuiltin(f"SetFocus({FIRST})")

    def clear(self, n):
        for p in ("path", "all", "title", "kind", "empty"):
            self.clearProperty(f"row{n - 200}.{p}")

    def near(self, focus):
        # rows up to AHEAD past the focus get their paths
        last = min(LAST, max(focus, FIRST) + AHEAD, FIRST + len(self.rows) - 1)
        while self.enabled < last:
            self.enabled += 1
            self.enable(self.enabled)

    def enable(self, n):
        title, path, kind = self.rows[n - FIRST]
        row = f"row{n - 200}"
        self.setProperty(f"{row}.title", title)
        self.setProperty(f"{row}.kind", kind)
        self.setProperty(f"{row}.all", path)
        self.setProperty(f"{row}.path", path + (f"&reload={self.stamp}" if self.stamp else ""))
        threading.Thread(target=self.empty, args=(n, self.loads), daemon=True).start()

    def empty(self, n, load):
        # a row that came back empty goes, the focus skips it
        if not self.wait(lambda: self.loaded(n) or load != self.loads, PATIENCE) and load == self.loads:
            self.setProperty(f"row{n - 200}.empty", "1")

    def loaded(self, n):
        return int(info(f"Container({n}).NumItems") or 0) > 0

    def wait(self, done, seconds=PATIENCE):
        monitor = xbmc.Monitor()
        for _ in range(int(seconds * 10)):
            if self.closing or monitor.abortRequested():
                return False
            if done():
                return True
            monitor.waitForAbort(0.1)
        return False

    # what downloads, the first row

    def poll(self):
        monitor = xbmc.Monitor()
        while not self.closing and not monitor.abortRequested():
            try:
                self.downloads()
            except RuntimeError:
                return
            if monitor.waitForAbort(POLL):
                return

    def downloads(self):
        found, _ = downloads()
        if self.closing:
            return
        keys = [key for key, *_ in found]
        if keys != self.keys:
            control = self.getControl(DOWNLOADS)
            control.reset()
            self.posters = []
            for key, records, _, props in found:
                what, art = poster(key[0], records)
                li = xbmcgui.ListItem(what.get("title") or props["label"])
                li.setArt({"poster": art, "fanart": next((i.get("remoteUrl") for i in what.get("images", []) if i.get("coverType") == "fanart"), "")})
                tag = li.getVideoInfoTag()
                tag.setMediaType("movie" if key[0] == "radarr" else "tvshow")
                tag.setPlot(what.get("overview", ""))
                if what.get("year"):
                    tag.setYear(int(what["year"]))
                if what.get("tmdbId"):
                    tag.setUniqueIDs({"tmdb": str(what["tmdbId"])}, "tmdb")
                self.posters.append(li)
            control.addItems(self.posters)
            self.keys = keys
            self.setProperty("row1.path", "downloads" if found else "")
            self.setProperty("row1.title", "Downloading" if found else "")
        for li, (_, _, _, props) in zip(self.posters, found):
            li.setProperty("progress", f"{props['percent']} · {props['state']}")

    # keys

    def onClick(self, cid):
        if cid == MOVIES:
            self.show("movie")
        elif cid == SHOWS:
            self.show("tv")
        elif cid == SEARCH:
            query = xbmcgui.Dialog().input("Search TMDb: films, shows, people", self.query).strip()
            if query:
                self.query = query
                self.show("search")
        elif cid == BROWSE:
            self.leave()
            xbmc.executebuiltin(f"ActivateWindow(Videos,{HELPER},return)")
        elif cid == DOWNLOADS:
            show_downloads()

    def onAction(self, action):
        a = action.getId()
        key = letter(action)
        focus = self.getFocusId()
        if a in (xbmcgui.ACTION_MOVE_UP, xbmcgui.ACTION_MOVE_DOWN, xbmcgui.ACTION_MOVE_LEFT, xbmcgui.ACTION_MOVE_RIGHT):
            self.moved = True
            if FIRST <= focus <= LAST:
                self.near(focus)
        elif key == "r":
            self.stamp = str(time.time())
            self.show(self.mode)
        elif key == "t" and DOWNLOADS <= focus <= LAST:
            tmdb = info(f"Container({focus}).ListItem.UniqueID(tmdb)") or info(f"Container({focus}).ListItem.Property(tmdb_id)")
            kind = "tv" if info(f"Container({focus}).ListItem.DBType") == "tvshow" else "movie"
            if tmdb:
                trailer(kind, tmdb)
        elif a in (xbmcgui.ACTION_NAV_BACK, xbmcgui.ACTION_PREVIOUS_MENU):
            if self.mode == "search":
                # back from what was found: the rows of before
                self.show(self.before)
            else:
                self.leave()

    def leave(self):
        self.closing = True
        self.close()


def discover():
    w = window(Discover, "moviepipe-discover.xml")
    w.doModal()
    w.closing = True
    del w
