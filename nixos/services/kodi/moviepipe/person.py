# a person's page (resources/skins/Default/1080i/moviepipe-person.xml): the
# photo and what tmdb knows of them, their films, shows or the films they
# directed, the known ones, the newest or the oldest first. tmdb helper
# fills it, its lists' paths in the window's properties: enter on a film is
# its player ("Download…"), i its page, c its menu, t its trailer, o its
# tmdb page in the browser (TMDB ↗: the person's), r the row again. the
# biography fades out under its lines, enter on it: all of it. majan's film
# page opens it (../majan-moviepipe.xml): enter on
# one of the cast, "more by director" (the film's director by its crew when
# tmdb helper's list gave no name)
import threading
import time
from datetime import date

import xbmc
import xbmcgui

from browser import browse, url
from keys import letter
from tmdb import count, helper, info, settle, wait
from trailer import trailer
from windows import window

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
# the hidden lists: the person's details, tmdb's people of that name, a
# film's crew
DETAILS, SEARCH, CREW, ROW = 70, 71, 72, 500
# the list's last tile (tmdb helper's next page), left on its first
NEXT, PREVIOUS, BIO, TMDB = 310, 311, 9001, 121
KINDS = {
    "Acting": "Actor",
    "Directing": "Director",
    "Writing": "Writer",
    "Production": "Producer",
    "Camera": "Cinematographer",
    "Editing": "Editor",
    "Sound": "Composer",
}


def day(text):
    try:
        return date.fromisoformat(text[:10]).strftime("%-d %b %Y")
    except ValueError:
        return text


def items(cid):
    # a hidden list's items: (label, item's infolabel prefix)
    for i in range(count(cid)):
        item = f"Container({cid}).ListItemAbsolute({i})"
        yield info(f"{item}.Label"), item


class Person(xbmcgui.WindowXML):
    def onInit(self):
        if getattr(self, "started", False):
            return
        self.started = True
        self.closing = False
        self.page = 1
        self.loads = 0
        self.stamp = ""
        self.counts = {}
        self.bio = ""
        self.setProperty("name", self.name)
        self.setProperty("empty", "Loading…")
        threading.Thread(target=self.load, daemon=True).start()

    def gone(self):
        return self.closing

    def filled(self, cid):
        # a hidden list (the details, a search, a crew) has its items
        return wait(lambda: count(cid) > 0, 30, self.gone)

    def search(self):
        # the first of that name, tmdb's most popular first
        self.setProperty("search", helper(info="search", tmdb_type="person", query=self.name))
        if not self.filled(SEARCH):
            return None
        found = [(label.casefold() != self.name.casefold(), n, info(f"{item}.Property(tmdb_id)")) for n, (label, item) in enumerate(items(SEARCH))]
        return min(found)[2] if found else None

    def director(self):
        # the film's director by its crew, a show's creator: tmdb helper's
        # lists have no director, only its page of the film does
        self.setProperty("crew", helper(info="crew", tmdb_type=self.kind, tmdb_id=self.film))
        if not self.filled(CREW):
            return None
        jobs = ("Creator", "Director") if self.kind == "tv" else ("Director",)
        found = []
        for label, item in items(CREW):
            roles = info(f"{item}.Property(role)").split(" / ")
            rank = next((n for n, job in enumerate(jobs) if job in roles), None)
            if rank is not None:
                found.append((rank, len(found), label, info(f"{item}.Property(tmdb_id)")))
        if not found:
            return None
        _, _, self.name, tmdb = min(found)
        self.setProperty("name", self.name)
        return tmdb

    def load(self):
        if not self.tmdb and self.film:
            self.tmdb = self.director()
        if not self.tmdb and self.name:
            self.tmdb = self.search()
        if not self.tmdb:
            self.setProperty("empty", f"No {self.name or 'director'} on TMDb")
            return
        self.setProperty("details", helper(info="details", tmdb_type="person", tmdb_id=self.tmdb))
        if self.filled(DETAILS):
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
        for tab, (*_, total) in TABS.items():
            self.counts[tab] = int(get(f"Property({total})") or 0)
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
        if self.stamp:
            params["reload"] = self.stamp
        self.setProperty("tab", self.tab)
        self.setProperty("sort", self.sort)
        self.setProperty("page", str(self.page))
        self.setProperty("rowtitle", f"{title} · {said}")
        total = self.counts.get(self.tab) if self.tab != "directed" else None
        said = [f"page {self.page}" if self.page > 1 else "", f"{total} in all" if total else ""]
        self.setProperty("rowcount", " · ".join(s for s in said if s))
        self.loads += 1
        threading.Thread(target=self.loaded, args=(self.loads, helper(**params)), daemon=True).start()

    def loaded(self, load, path):
        # the old posters dim till the new ones are in (the xml), then the
        # first of them, or "Nothing here"
        self.setProperty("loading", "1")
        self.setProperty("path", path)
        found = settle(ROW, lambda: self.gone() or load != self.loads)
        if load != self.loads or self.closing:
            return
        self.setProperty("loading", "")
        self.setProperty("empty", "" if found else "Nothing here")
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
        elif cid == TMDB:
            browse(url("tmdb", "person", self.tmdb))
            return
        else:
            return
        self.show()

    def onAction(self, action):
        a = action.getId()
        key = letter(action)
        if key == "r" and self.tmdb and self.tab:
            # the row again, tmdb helper asked anew
            self.stamp = str(time.time())
            self.show()
        elif key == "o" and self.getFocusId() == ROW:
            # the film's or show's page in the browser
            kind = "tv" if info(f"Container({ROW}).ListItem.DBType") == "tvshow" else "movie"
            browse(url("tmdb", kind, info(f"Container({ROW}).ListItem.UniqueID(tmdb)") or info(f"Container({ROW}).ListItem.Property(tmdb_id)")))
        elif key == "t" and self.getFocusId() == ROW:
            tmdb = info(f"Container({ROW}).ListItem.UniqueID(tmdb)") or info(f"Container({ROW}).ListItem.Property(tmdb_id)")
            kind = "tv" if info(f"Container({ROW}).ListItem.DBType") == "tvshow" else "movie"
            if tmdb:
                trailer(kind, tmdb)
        elif a in (xbmcgui.ACTION_NAV_BACK, xbmcgui.ACTION_PREVIOUS_MENU):
            self.closing = True
            self.close()


def person(tmdb=None, name="", tab=None, film=None, kind="movie"):
    # by tmdb's id (the cast), the director of a film (film's tmdb id), or
    # the first of the names
    name = name.strip('"').split(" / ")[0].strip()
    if film and kind == "tv":
        # a show's creator: the tab they have the most of
        tab = None
    # the film's page goes, this one comes up in its place
    xbmc.executebuiltin("Dialog.Close(all,true)", True)
    w = window(
        Person,
        "moviepipe-person.xml",
        tmdb=tmdb or None,
        film=film or None,
        kind="tv" if kind == "tv" else "movie",
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
