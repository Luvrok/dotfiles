# 5, discover (resources/skins/Default/1080i/moviepipe-discover.xml): what
# tmdb has in rows, majan's hub rows, films or shows (the chips): trending,
# popular, in cinemas, upcoming, top rated, more like the library's newest,
# popular people; what radarr and sonarr download first. tmdb helper fills
# them (the rows' paths are the window's properties), so enter on a film is
# its player (Download…), i its page, c its menu; a show's enter is its
# page, a person's theirs (./person.py), a download's the downloads. the
# last tile turns the row's page, left on the first one back. a row gets
# its path when the focus is two rows from it: tmdb helper asks tmdb for
# every poster's details the first time. SEARCH: what tmdb finds, back
# the rows again. t a trailer, r the rows again
import threading
import time

import xbmc
import xbmcgui

from actions import rpc
from arr import Error
from keys import letter
from tmdb import HELPER, helper, info, settle
from trailer import trailer
from windows import downloads, window

# (the row's name, tmdb helper's list, what's on it). the order here is the
# page's, rows 2 on. {} in a name: the library's newest film or show
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
# row n is list 200 + n: 1 the downloads (./default.py's queue), 2..8 tmdb's
QUEUE = "plugin://plugin.video.moviepipe/?action=queue"
FIRST, LAST = 2, 8
# the chips, and the rows' SendClick: 40 + n the next page, 50 + n back
MOVIES, SHOWS, SEARCH, BROWSE = 101, 102, 103, 104
NEXT, BACK = 40, 50
# rows past the focus that get their path
AHEAD = 2
# s: how often the focus and the downloads are looked at
TICK = 0.2
POLL = 10


def newest(kind):
    # the library's last added film or show: (title, tmdb id)
    method, key = ("VideoLibrary.GetMovies", "movies") if kind == "movie" else ("VideoLibrary.GetTVShows", "tvshows")
    try:
        found = rpc(method, properties=["title", "uniqueid"], sort={"method": "dateadded", "order": "descending"}, limits={"end": 10}).get(key) or []
    except Error:
        return None
    return next(((x["title"], x["uniqueid"]["tmdb"]) for x in found if (x.get("uniqueid") or {}).get("tmdb")), None)


class Row:
    # a row's name, tmdb helper's params for it, what's on it, its page
    def __init__(self, title, params, kind):
        self.title, self.params, self.kind, self.page = title, params, kind, 1


class Discover(xbmcgui.WindowXML):
    def onInit(self):
        if getattr(self, "started", False):
            return
        self.started = True
        self.closing = False
        self.moved = False
        self.rows = {}
        self.enabled = FIRST - 1
        self.loads = 0
        self.stamp = ""
        self.query = ""
        self.mode = self.before = "movie"
        self.queue = None
        self.show("movie")
        threading.Thread(target=self.watch, daemon=True).start()

    def gone(self):
        return self.closing

    # the rows

    def show(self, mode):
        if mode != "search":
            self.before = mode
        self.mode = mode
        self.setProperty("mode", mode)
        self.setProperty("query", f"«{self.query}»" if mode == "search" else "")
        rows = []
        for title, kind, what in ROWS[mode]:
            params = dict(info=kind, tmdb_type=what)
            if kind == "recommendations":
                found = newest(what)
                if not found:
                    continue
                title = title.format(found[0])
                params["tmdb_id"] = found[1]
            if kind == "search":
                params["query"] = self.query
            rows.append(Row(title, params, what))
        self.rows = {FIRST + i: row for i, row in enumerate(rows)}
        self.loads += 1
        load = self.loads
        # the rows near the top get the new paths at once (the old posters
        # dim till the new come, majan-moviepipe.xml), the rest go
        self.enabled = FIRST - 1
        for n in range(FIRST, LAST + 1):
            self.clearProperty(f"row{n}.empty")
            if n not in self.rows or n > FIRST + AHEAD:
                for p in ("path", "title", "sub", "index", "kind", "page"):
                    self.clearProperty(f"row{n}.{p}")
        self.near(FIRST)
        threading.Thread(target=self.first, args=(load,), daemon=True).start()

    def first(self, load):
        # the first row on top once it's in (the old rows' tile stood there
        # otherwise), the focus on it unless it went elsewhere
        if not settle(200 + FIRST, lambda: self.gone() or load != self.loads) or load != self.loads:
            return
        if not 201 <= self.getFocusId() <= 200 + LAST:
            self.setProperty("row", str(200 + FIRST))
        if not self.moved:
            self.setProperty("row", str(200 + FIRST))
            xbmc.executebuiltin(f"SetFocus({200 + FIRST})")

    def near(self, focus):
        # the rows up to AHEAD past the focus get their paths
        last = min(LAST, max(focus, FIRST) + AHEAD, FIRST + len(self.rows) - 1)
        while self.enabled < last:
            self.enabled += 1
            self.put(self.enabled)

    def put(self, n):
        # row n's properties, its path last: a new path loads it
        row = self.rows[n]
        page = row.page if row.page > 1 else None
        self.setProperty(f"row{n}.index", f"{n - 1:02}")
        self.setProperty(f"row{n}.title", row.title)
        self.setProperty(f"row{n}.sub", f"page {row.page}" if page else "TMDb")
        self.setProperty(f"row{n}.kind", row.kind)
        self.setProperty(f"row{n}.page", str(row.page))
        self.setProperty(f"row{n}.path", helper(**row.params, page=page, reload=self.stamp))
        threading.Thread(target=self.empty, args=(n, self.loads), daemon=True).start()

    def empty(self, n, load):
        # a row that came back empty goes, the focus skips it
        if not settle(200 + n, lambda: self.gone() or load != self.loads) and load == self.loads and not self.gone():
            self.setProperty(f"row{n}.empty", "1")

    def turn(self, n, by):
        # the row's next page (by 1) or the one before (-1), its first tile
        row = self.rows.get(n)
        if not row or row.page + by < 1:
            return
        row.page += by
        self.put(n)

        def first():
            if settle(200 + n, self.gone):
                try:
                    self.getControl(200 + n).selectItem(0)
                except RuntimeError:
                    pass

        threading.Thread(target=first, daemon=True).start()

    # what's in focus, what downloads

    def watch(self):
        # the row whose tile is on top: the one with the focus, the last one
        # when it went up to the chips (the mouse too, it moves no action)
        monitor = xbmc.Monitor()
        polled = 0
        while not self.closing and not monitor.waitForAbort(TICK):
            try:
                focus = self.getFocusId()
                if 201 <= focus <= 200 + LAST and str(focus) != self.getProperty("row"):
                    self.setProperty("row", str(focus))
                    if focus > 200 + FIRST:
                        self.moved = True
                    self.near(focus - 200)
                if time.time() - polled > POLL:
                    polled = time.time()
                    self.downloads()
            except RuntimeError:
                return

    def downloads(self):
        # the first row while something downloads, again when that changed
        found, _ = downloads()
        keys = [(key, row["percent"]) for key, _, _, row in found]
        if keys == self.queue or self.closing:
            return
        self.queue = keys
        if not found:
            for p in ("path", "title", "sub", "index", "kind"):
                self.clearProperty(f"row1.{p}")
            return
        self.setProperty("row1.index", "06")
        self.setProperty("row1.title", "Downloading")
        self.setProperty("row1.sub", "Radarr · Sonarr")
        self.setProperty("row1.kind", "downloads")
        self.setProperty("row1.path", f"{QUEUE}&reload={time.time()}")

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
        elif NEXT < cid <= NEXT + LAST:
            self.turn(cid - NEXT, 1)
        elif BACK < cid <= BACK + LAST:
            self.turn(cid - BACK, -1)

    def onAction(self, action):
        a = action.getId()
        key = letter(action)
        focus = self.getFocusId()
        if a in (xbmcgui.ACTION_MOVE_UP, xbmcgui.ACTION_MOVE_DOWN, xbmcgui.ACTION_MOVE_LEFT, xbmcgui.ACTION_MOVE_RIGHT):
            self.moved = True
        elif key == "r":
            # every row again, tmdb helper asked anew
            self.stamp = str(time.time())
            for n in range(FIRST, self.enabled + 1):
                self.put(n)
        elif key == "t" and 201 <= focus <= 200 + LAST:
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
