# majan's "more by director" on a film's page (../majan.nix): the films
# its director directed, on tmdb, tmdb helper's list of them in videos, the
# known ones first. enter on one is movie pipe's players again
# (../default.nix)
import urllib.parse

import xbmc

HELPER = "plugin://plugin.video.themoviedb.helper/"


def director(name):
    # the first of the names, "Lana Wachowski / Lilly Wachowski"
    name = name.strip('"').split(" / ")[0].strip()
    params = dict(
        info="crew_in_movies",
        tmdb_type="person",
        query=name,
        filter_key="job",
        filter_value="Director",
        filter_operator="eq",
        sort_by="votes",
        sort_how="desc",
    )
    # the film's page goes, the list comes up in its place
    xbmc.executebuiltin("Dialog.Close(all,true)")
    xbmc.executebuiltin(f"ActivateWindow(Videos,{HELPER}?{urllib.parse.urlencode(params)},return)")
