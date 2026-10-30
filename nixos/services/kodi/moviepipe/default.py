# Movie pipe in video add-ons, and its routes:
#   ?action=downloads  what radarr and sonarr download (6, ../keyboard.xml),
#                      ./windows.py
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
import sys
import time
import urllib.parse

import xbmc
import xbmcgui
import xbmcplugin

from actions import movie, show
from arr import Error, error
from discover import discover
from person import person
from trailer import trailer
from windows import show_downloads

HANDLE = int(sys.argv[1])
QUERY = dict(urllib.parse.parse_qsl(sys.argv[2][1:]))


def listing():
    # opened in video add-ons: no folder, the downloads' window
    xbmcplugin.endOfDirectory(HANDLE, succeeded=False)
    xbmc.executebuiltin(f"RunPlugin({sys.argv[0]}?action=downloads)")


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


action = QUERY.get("action")
if action == "downloads":
    show_downloads()
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
else:
    listing()
