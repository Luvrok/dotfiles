# Movie pipe in video add-ons, and its routes:
#   ?action=downloads  what radarr and sonarr download (6, ../keyboard.xml),
#                      ./windows.py
#   ?action=queue      the same as a folder of posters: discover's first row,
#                      the top bar's 06 (../majan-moviepipe.xml)
#   ?action=discover   tmdb's trending, popular, new (5), ./discover.py
#   ?action=download&type=movie|episode&tmdb=...  ./actions.py for tmdb
#                      helper's player (../userdata.nix), enter on a film
#                      there. pick: the same, its old name
#   ?action=person&tmdb=...|film=...&type=movie|tv|name=...[&tab=...]
#                      ./person.py, a person's page (majan's film page: the
#                      cast, "more by director", its director by the film)
#   ?action=trailer&type=movie|tv&tmdb=...  ./trailer.py, majan's film page
#   ?action=reload     r on majan's film page: its cast row again
#                      (../majan-moviepipe.xml)
#   ?action=open&site=tmdb|imdb|letterboxd&type=movie|tv|person&tmdb=&imdb=
#                      the page in the browser, ./browser.py (more on the
#                      film page)
#   ?action=plot&id=N  the whole plot of container N's tile (home's rows)
#   ?action=page&row=N&by=1|-1  home's row N's page of tmdb helper
import sys
import time
import urllib.parse

import xbmc
import xbmcgui
import xbmcplugin

from actions import movie, show
from arr import Error, error
from browser import browse, url
from discover import discover
from person import person
from tmdb import info, settle
from trailer import trailer
from windows import downloads, show_downloads

HANDLE = int(sys.argv[1])
QUERY = dict(urllib.parse.parse_qsl(sys.argv[2][1:]))


def listing():
    # opened in video add-ons: no folder, the downloads' window
    xbmcplugin.endOfDirectory(HANDLE, succeeded=False)
    xbmc.executebuiltin(f"RunPlugin({sys.argv[0]}?action=downloads)")


def queue():
    # a poster a download: radarr's film or sonarr's show, its progress
    found, _ = downloads()
    items = []
    for key, records, _, row in found:
        what = records[0].get("movie" if key[0] == "radarr" else "series") or {}
        art = {i.get("coverType"): i.get("remoteUrl") for i in what.get("images", [])}
        li = xbmcgui.ListItem(what.get("title") or row["label"])
        li.setArt({"poster": art.get("poster", ""), "fanart": art.get("fanart", "")})
        li.setProperty("progress", f"{row['percent']} · {row['state']}")
        tag = li.getVideoInfoTag()
        tag.setMediaType("movie" if key[0] == "radarr" else "tvshow")
        tag.setPlot(what.get("overview", ""))
        if what.get("year"):
            tag.setYear(int(what["year"]))
        if what.get("tmdbId"):
            tag.setUniqueIDs({"tmdb": str(what["tmdbId"])}, "tmdb")
        items.append((f"{sys.argv[0]}?action=downloads", li, False))
    xbmcplugin.setContent(HANDLE, "movies")
    xbmcplugin.addDirectoryItems(HANDLE, items, len(items))
    xbmcplugin.endOfDirectory(HANDLE, cacheToDisc=False)


def player():
    tmdb = int(QUERY["tmdb"])
    try:
        if QUERY["type"] == "movie":
            movie(tmdb)
        else:
            show(tmdb, QUERY["type"], int(QUERY["season"]), int(QUERY["episode"]))
    except Error as e:
        error(e)


def reload():
    # the stamp in the cast row's path: a new path, the row asks tmdb
    # helper again
    xbmcgui.Window(10000).setProperty("moviepipe.reload", str(time.time()))


def plot():
    # a tile's whole plot, home's rows (its info shows a few lines of it)
    cid = QUERY["id"]
    xbmcgui.Dialog().textviewer(info(f"Container({cid}).ListItem.Label"), info(f"Container({cid}).ListItem.Plot"))


def page():
    # home's row turns its page in place (../majan-moviepipe.xml: its path
    # has the page of this property), its first tile in focus then
    row, home = QUERY["row"], xbmcgui.Window(10000)
    key = f"moviepipe.page{row}"
    n = max(1, int(home.getProperty(key) or 1) + int(QUERY.get("by", 1)))
    home.setProperty(key, str(n) if n > 1 else "")
    if settle(row):
        xbmc.executebuiltin(f"SetFocus({row},0,absolute)")


action = QUERY.get("action")
if action == "downloads":
    show_downloads()
elif action == "queue":
    queue()
elif action == "discover":
    discover()
elif action in ("download", "pick"):
    player()
elif action == "person":
    person(QUERY.get("tmdb"), QUERY.get("name", ""), QUERY.get("tab"), QUERY.get("film"), QUERY.get("type", "movie"))
elif action == "trailer":
    trailer(QUERY.get("type", "movie"), QUERY.get("tmdb"))
elif action == "reload":
    reload()
elif action == "open":
    browse(url(QUERY.get("site", "tmdb"), QUERY.get("type", "movie"), QUERY.get("tmdb"), QUERY.get("imdb")))
elif action == "plot":
    plot()
elif action == "page":
    page()
else:
    listing()
