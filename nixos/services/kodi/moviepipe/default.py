# Movie pipe in video add-ons, and its routes:
#   ?action=downloads  what radarr and sonarr download (6, ../keyboard.xml),
#                      ./windows.py
#   ?action=pick|download&type=movie|episode&tmdb=...  ./actions.py for
#                      tmdb helper's players (../default.nix), enter on a
#                      film there
#   ?action=director&name=...  ./director.py, the director's films on tmdb
#                      (majan's film page)
import sys
import urllib.parse

import xbmc
import xbmcplugin

from actions import movie, show
from arr import Error, error
from director import director
from windows import show_downloads

HANDLE = int(sys.argv[1])
QUERY = dict(urllib.parse.parse_qsl(sys.argv[2][1:]))


def listing():
    # opened in video add-ons: no folder, the downloads' window
    xbmcplugin.endOfDirectory(HANDLE, succeeded=False)
    xbmc.executebuiltin(f"RunPlugin({sys.argv[0]}?action=downloads)")


def player():
    pick = QUERY["action"] == "pick"
    tmdb = int(QUERY["tmdb"])
    try:
        if QUERY["type"] == "movie":
            movie(tmdb, pick)
        else:
            show(tmdb, QUERY["type"], int(QUERY["season"]), int(QUERY["episode"]), pick)
    except Error as e:
        error(e)


action = QUERY.get("action")
if action == "downloads":
    show_downloads()
elif action in ("pick", "download"):
    player()
elif action == "director":
    director(QUERY.get("name", ""))
else:
    listing()
