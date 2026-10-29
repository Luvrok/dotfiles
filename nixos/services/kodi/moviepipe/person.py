# a person's page (resources/skins/Default/1080i/moviepipe-person.xml): the
# photo and what tmdb knows of them, their films, shows or the films they
# directed, the known ones, the newest or the oldest first. tmdb helper
# fills it, its lists' paths in the window's properties: enter on a film is
# its players ("Download", "Pick a release…"), i its page, c its menu.
# majan's film page opens it
# (../majan-moviepipe.xml): enter on one of the cast, "more by director"
import threading
import urllib.parse
from datetime import date

import xbmc
import xbmcgui

from windows import window

HELPER = "plugin://plugin.video.themoviedb.helper/"
# the tabs: the button, tmdb helper's list and more of its params, the
# row's name, the person's count of them (tmdb helper's details)
TABS = {
    "films": (101, "stars_in_movies", {}, "Films", "numitems.tmdb.movies.cast"),
    "tv": (102, "stars_in_tvshows", {}, "TV shows", "numitems.tmdb.tvshows.cast"),
    "directed": (
        103,
        "crew_in_movies",
        {"filter_key": "job", "filter_value": "Director", "filter_operator": "eq"},
        "Directed",
        "numitems.tmdb.movies.crew",
    ),
}
# votes: the known ones first
SORTS = {
    "popular": (111, "votes", "desc", "most popular first"),
    "newest": (112, "year", "desc", "newest first"),
    "oldest": (113, "year", "asc", "oldest first"),
}
# the hidden lists: the person's details, tmdb's people of that name
DETAILS, SEARCH, ROW = 70, 71, 500
# the list's last tile (tmdb helper's next page), left on its first
NEXT, PREVIOUS, BIO = 310, 311, 9001
KINDS = {
    "Acting": "Actor",
    "Directing": "Director",
    "Writing": "Writer",
    "Production": "Producer",
    "Camera": "Cinematographer",
    "Editing": "Editor",
    "Sound": "Composer",
}


def info(label):
    return xbmc.getInfoLabel(label)


def day(text):
    try:
        return date.fromisoformat(text[:10]).strftime("%-d %b %Y")
    except ValueError:
        return text


class Person(xbmcgui.WindowXML):
    def onInit(self):
        if getattr(self, "started", False):
            return
        self.started = True
        self.closing = False
        self.page = 1
        self.loads = 0
        self.counts = {}
        self.bio = ""
        self.setProperty("name", self.name)
        self.setProperty("empty", "Loading…")
        threading.Thread(target=self.load, daemon=True).start()

    def wait(self, cid, seconds=30):
        monitor = xbmc.Monitor()
        for _ in range(seconds * 4):
            if self.closing or monitor.abortRequested():
                return False
            if int(info(f"Container({cid}).NumItems") or 0) > 0:
                return True
            monitor.waitForAbort(0.25)
        return False

    def search(self):
        # the first of that name, tmdb's most popular first
        self.setProperty("search", f"{HELPER}?{urllib.parse.urlencode(dict(info='search', tmdb_type='person', query=self.name))}")
        if not self.wait(SEARCH):
            return None
        found = []
        for i in range(int(info(f"Container({SEARCH}).NumItems") or 0)):
            item = f"Container({SEARCH}).ListItemAbsolute({i})"
            found.append((info(f"{item}.Label").casefold() != self.name.casefold(), i, info(f"{item}.Property(tmdb_id)")))
        return min(found)[2] if found else None

    def load(self):
        if not self.tmdb:
            self.tmdb = self.search()
        if not self.tmdb:
            self.setProperty("empty", f"No {self.name} on TMDb")
            return
        self.setProperty("details", f"{HELPER}?{urllib.parse.urlencode(dict(info='details', tmdb_type='person', tmdb_id=self.tmdb))}")
        if self.wait(DETAILS):
            self.details()
        if not self.tab:
            if self.department == "Directing" and self.counts.get("directed"):
                self.tab = "directed"
            else:
                self.tab = next((t for t in ("films", "tv", "directed") if self.counts.get(t)), "films")
        # the focus on its tab, the first of the row before the tabs came:
        # through kodi, a control's own setFocusId is the ui thread's
        buttons = [v[0] for v in TABS.values()] + [v[0] for v in SORTS.values()]
        if self.getFocusId() in buttons:
            xbmc.executebuiltin(f"SetFocus({TABS[self.tab][0]})")
        self.show()

    def details(self):
        def get(x):
            return info(f"Container({DETAILS}).ListItemAbsolute(0).{x}")

        self.name = get("Label") or self.name
        self.bio = get("Plot")
        self.department = get("Property(department)")
        died = get("Property(deathday)")
        for tab, (*_, count) in TABS.items():
            self.counts[tab] = int(get(f"Property({count})") or 0)
        # the directed: of all they did behind the camera, the tab says
        # if there's none. the others only with some
        for tab in TABS:
            self.setProperty(f"has_{tab}", "1" if self.counts[tab] or self.tab == tab else "")
        self.setProperty("name", self.name)
        self.setProperty("bio", self.bio)
        self.setProperty("kind", KINDS.get(self.department, self.department or "Person"))
        self.setProperty("kicker", f"Known for {self.department}" if self.department else "")
        self.setProperty("born", day(get("Property(birthday)")))
        self.setProperty("died", day(died))
        self.setProperty("age", get("Property(age)"))
        self.setProperty("place", get("Property(born)"))
        self.setProperty("films", str(self.counts["films"] or ""))
        self.setProperty("tvshows", str(self.counts["tv"] or ""))

    def show(self):
        _, kind, extra, title, _ = TABS[self.tab]
        _, by, how, said = SORTS[self.sort]
        params = dict(info=kind, tmdb_type="person", tmdb_id=self.tmdb, sort_by=by, sort_how=how, **extra)
        if self.page > 1:
            params["page"] = self.page
        self.setProperty("tab", self.tab)
        self.setProperty("sort", self.sort)
        self.setProperty("page", str(self.page))
        self.setProperty("rowtitle", f"{title} · {said}")
        total = self.counts.get(self.tab) if self.tab != "directed" else None
        said = [f"page {self.page}" if self.page > 1 else "", f"{total} in all" if total else ""]
        self.setProperty("rowcount", " · ".join(s for s in said if s))
        self.setProperty("empty", "Loading…")
        self.setProperty("path", f"{HELPER}?{urllib.parse.urlencode(params)}")
        self.loads += 1
        threading.Thread(target=self.loaded, args=(self.loads,), daemon=True).start()

    def loaded(self, load):
        found = self.wait(ROW)
        if load != self.loads:
            return
        self.setProperty("empty", "" if found else "Nothing here" if not self.closing else "")
        if found:
            # a list's own call, off the ui thread: gone with the window
            try:
                self.getControl(ROW).selectItem(0)
            except RuntimeError:
                pass

    def onClick(self, cid):
        tabs = {v[0]: k for k, v in TABS.items()}
        sorts = {v[0]: k for k, v in SORTS.items()}
        if not self.tmdb:
            return
        if cid in tabs:
            self.tab, self.page = tabs[cid], 1
        elif cid in sorts:
            self.sort, self.page = sorts[cid], 1
        elif cid == NEXT:
            self.page += 1
        elif cid == PREVIOUS and self.page > 1:
            self.page -= 1
        elif cid == BIO:
            xbmcgui.Dialog().textviewer(self.name, self.bio)
            return
        else:
            return
        self.show()

    def onAction(self, action):
        a = action.getId()
        btn = action.getButtonCode()
        if btn == ord("r"):
            # rescan: reload current tab
            self.loads += 1
            threading.Thread(target=self.loaded, args=(self.loads,), daemon=True).start()
            return
        if a in (xbmcgui.ACTION_NAV_BACK, xbmcgui.ACTION_PREVIOUS_MENU):
            self.closing = True
            self.close()


def person(tmdb=None, name="", tab=None):
    # by tmdb's id (the cast), or the first of the names (directors)
    name = name.strip('"').split(" / ")[0].strip()
    # the film's page goes, this one comes up in its place
    xbmc.executebuiltin("Dialog.Close(all,true)", True)
    w = window(
        Person,
        "moviepipe-person.xml",
        tmdb=tmdb or None,
        name=name,
        tab=tab if tab in TABS else None,
        sort="popular",
        department="",
    )
    # every tab till tmdb says which there are: the focus on the first
    for each in TABS:
        w.setProperty(f"has_{each}", "1")
    w.doModal()
    w.closing = True
    del w
