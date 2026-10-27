# an actor's or a director's films and shows on tmdb (majan's film page,
# ../majan-moviepipe.xml: enter on one of the cast, "РЕЖИССЁР"): which of
# them and in what order, then tmdb helper's list of them in videos. enter
# on a film there is movie pipe's players again (../default.nix)
import urllib.parse

import xbmc
import xbmcgui

HELPER = "plugin://plugin.video.themoviedb.helper/"
# what's shown, tmdb helper's list, its sort: votes, the known ones first
ACTED = [
    ("Фильмы — самые известные", "stars_in_movies", "votes", "desc"),
    ("Фильмы — новые сначала", "stars_in_movies", "year", "desc"),
    ("Фильмы — старые сначала", "stars_in_movies", "year", "asc"),
    ("Сериалы — самые известные", "stars_in_tvshows", "votes", "desc"),
    ("Сериалы — новые сначала", "stars_in_tvshows", "year", "desc"),
]
CREW = [
    ("За кадром — самые известные", "crew_in_movies", "votes", "desc"),
    ("За кадром — новые сначала", "crew_in_movies", "year", "desc"),
    ("За кадром — сериалы", "crew_in_tvshows", "votes", "desc"),
]
EVERYTHING = [("Всё о человеке", "details", None, None)]


def person(tmdb=None, name="", crew=False):
    # by tmdb's id (the cast), or the first of the names (directors)
    name = name.strip('"').split(" / ")[0].strip()
    who = {"tmdb_id": tmdb} if tmdb else {"query": name}
    lists = (CREW + ACTED if crew else ACTED + CREW) + EVERYTHING
    i = xbmcgui.Dialog().select(name or "Фильмография", [label for label, *_ in lists])
    if i < 0:
        return
    _, info, sort_by, sort_how = lists[i]
    params = dict(info=info, tmdb_type="person", **who)
    if sort_by:
        params.update(sort_by=sort_by, sort_how=sort_how)
    # the film's page goes, the list comes up in its place
    xbmc.executebuiltin("Dialog.Close(all,true)")
    xbmc.executebuiltin(f"ActivateWindow(Videos,{HELPER}?{urllib.parse.urlencode(params)},return)")
