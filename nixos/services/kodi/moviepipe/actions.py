# what the menu (c, context.py) and tmdb helper's player (../userdata.nix,
# default.py) do with a film or a show:
#   download: the film goes to radarr, the show to sonarr, the trackers'
#     releases come in a list (windows.choose), the one picked downloads.
#     nobody downloads on their own: nothing picked, nothing is added. a
#     show asks which seasons, then each one's releases, one after another
#   delete: radarr or sonarr delete it with its files (they can, kodi
#     can't write there), kodi's library forgets it. radarr and sonarr
#     don't download it again: the film or show is gone from them, a
#     season or an episode isn't wanted any more
import json
import os
import time

import xbmc
import xbmcgui

from arr import Api, Error, notify, waiting
from windows import choose

# s: a film or a show looked up or added, radarr and sonarr wait for their
# servers of metadata (skyhook) up to 100 s
LOOKUP = 150


def movie(tmdb):
    radarr = Api("radarr")
    have = radarr.get("/movie", tmdbId=tmdb)
    added = not have
    if have:
        m = have[0]
    else:
        m = waiting("Radarr", "Looking up the film…", lambda: radarr.get("/movie/lookup/tmdb", timeout=LOOKUP, tmdbId=tmdb))
        if m is None:
            return
        # wanted from the day it's announced, the profile keeps cams out
        m.update(radarr.new(), monitored=True, minimumAvailability="announced")
        m["addOptions"] = {"searchForMovie": False}
        m = radarr.post("/movie", m, timeout=LOOKUP)
    title = f"{m['title']} ({m['year']})"
    if choose(radarr, title, movieId=m["id"]) is None and added:
        # nothing picked: not even radarr's to look for later
        radarr.delete(f"/movie/{m['id']}")


def episodes(sonarr, series):
    # a show just added gets its episodes a few seconds later
    for _ in range(60):
        found = sonarr.get("/episode", seriesId=series)
        if found:
            return found
        time.sleep(1)
    raise Error("sonarr: the show has no episodes")


def show(tmdb, kind, season, episode):
    sonarr = Api("sonarr")
    found = waiting("Sonarr", "Looking up the show…", lambda: sonarr.get("/series/lookup", timeout=LOOKUP, term=f"tmdb:{tmdb}"))
    if found is None:
        return
    if not found:
        raise Error("sonarr didn't find the show")
    s = found[0]
    title = s["title"]

    if kind == "tvshow":
        numbers = [x["seasonNumber"] for x in s["seasons"] if x["seasonNumber"] > 0]
        picked = xbmcgui.Dialog().multiselect(f"{title}: seasons", [f"Season {n}" for n in numbers])
        if not picked:
            return
        chosen = [numbers[i] for i in picked]
    else:
        chosen = [season]
    # an episode alone: none of its season
    whole = kind != "episode"

    added = not s.get("id")
    # the seasons wanted before: one wanted only for this and nothing
    # picked for it is not wanted again (sonarr would find one itself)
    before = {x["seasonNumber"]: x.get("monitored", False) for x in s["seasons"]} if not added else {}
    if added:
        for x in s["seasons"]:
            x["monitored"] = whole and x["seasonNumber"] in chosen
        s.update(
            sonarr.new(),
            monitored=True,
            seasonFolder=True,
            seriesType="anime" if "Anime" in s.get("genres", []) else "standard",
        )
        s["addOptions"] = {"monitor": "skip", "searchForMissingEpisodes": False}
        s = sonarr.post("/series", s, timeout=LOOKUP)
    else:
        s = sonarr.get(f"/series/{s['id']}")
        wanted = all(x["monitored"] for x in s["seasons"] if x["seasonNumber"] in chosen)
        if (whole and not wanted) or not s["monitored"]:
            for x in s["seasons"]:
                x["monitored"] = x["monitored"] or (whole and x["seasonNumber"] in chosen)
            s["monitored"] = True
            s = sonarr.put(f"/series/{s['id']}", s)

    found = episodes(sonarr, s["id"])
    got = False
    if not whole:
        name = f"{title} S{season:02}E{episode:02}"
        ep = next((e for e in found if (e["seasonNumber"], e["episodeNumber"]) == (season, episode)), None)
        if ep is None:
            raise Error(f"sonarr: no episode {name}")
        sonarr.put("/episode/monitor", {"episodeIds": [ep["id"]], "monitored": True})
        got = choose(sonarr, name, episodeId=ep["id"]) is not None
    else:
        # one season's releases after another, esc on one goes to the next
        skipped = []
        for n in chosen:
            if choose(sonarr, f"{title}, season {n}", seriesId=s["id"], seasonNumber=n) is None:
                skipped.append(n)
        got = len(skipped) < len(chosen)
        skipped = [n for n in skipped if not before.get(n)]
        if got and skipped:
            s = sonarr.get(f"/series/{s['id']}")
            for x in s["seasons"]:
                if x["seasonNumber"] in skipped:
                    x["monitored"] = False
            sonarr.put(f"/series/{s['id']}", s)
    if not got and added:
        sonarr.delete(f"/series/{s['id']}")


def rpc(method, **params):
    found = json.loads(xbmc.executeJSONRPC(json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params})))
    if "error" in found:
        raise Error(f"kodi: {method}: {found['error'].get('message')}")
    return found.get("result") or {}


def inside(path, folder):
    # a file or folder of kodi's under radarr's or sonarr's folder
    folder = folder.rstrip("/") + "/"
    return (path.rstrip("/") + "/").startswith(folder)


def ids(details):
    unique = details.get("uniqueid") or {}

    def number(key):
        try:
            return int(unique.get(key) or 0)
        except ValueError:
            return 0

    return number("tmdb"), number("tvdb"), unique.get("imdb") or ""


def delete(kind, dbid):
    # kodi's own record of it: its files and ids, the show of a season or an
    # episode
    if kind == "movie":
        d = rpc("VideoLibrary.GetMovieDetails", movieid=dbid, properties=["file", "uniqueid", "title", "year"])["moviedetails"]
        tmdb, _, imdb = ids(d)
        radarr = Api("radarr")
        m = next(
            (m for m in radarr.get("/movie") if (tmdb and m.get("tmdbId") == tmdb) or (imdb and m.get("imdbId") == imdb) or inside(d["file"], m["path"])),
            None,
        )
        if m is None:
            raise Error(f"radarr doesn't have {d['title']}")
        name = f"{m['title']} ({m['year']})"
        if not xbmcgui.Dialog().yesno("Delete from disk", f"{name}\n\nRadarr deletes the film and its files. It won't be downloaded again."):
            return
        radarr.delete(f"/movie/{m['id']}", deleteFiles="true", addImportExclusion="false")
        rpc("VideoLibrary.RemoveMovie", movieid=dbid)
        notify(name, "Deleted")
        return

    if kind == "tvshow":
        show = dbid
    elif kind == "season":
        show = rpc("VideoLibrary.GetSeasonDetails", seasonid=dbid, properties=["tvshowid"])["seasondetails"]["tvshowid"]
    else:
        e = rpc("VideoLibrary.GetEpisodeDetails", episodeid=dbid, properties=["tvshowid", "season", "episode"])["episodedetails"]
        show = e["tvshowid"]
    d = rpc("VideoLibrary.GetTVShowDetails", tvshowid=show, properties=["file", "uniqueid", "title"])["tvshowdetails"]
    tmdb, tvdb, imdb = ids(d)
    sonarr = Api("sonarr")
    s = next(
        (
            s
            for s in sonarr.get("/series")
            if (tmdb and s.get("tmdbId") == tmdb) or (tvdb and s.get("tvdbId") == tvdb) or (imdb and s.get("imdbId") == imdb) or inside(d["file"], s["path"])
        ),
        None,
    )
    if s is None:
        raise Error(f"sonarr doesn't have {d['title']}")

    if kind == "tvshow":
        if not xbmcgui.Dialog().yesno("Delete from disk", f"{s['title']}\n\nSonarr deletes the show and all its files. It won't be downloaded again."):
            return
        sonarr.delete(f"/series/{s['id']}", deleteFiles="true", addImportListExclusion="false")
        rpc("VideoLibrary.RemoveTVShow", tvshowid=show)
        notify(s["title"], "Deleted")
        return

    if kind == "season":
        number = rpc("VideoLibrary.GetSeasonDetails", seasonid=dbid, properties=["season"])["seasondetails"]["season"]
        name = f"{s['title']}, season {number}"
        mine = [x for x in sonarr.get("/episode", seriesId=s["id"]) if x["seasonNumber"] == number]
    else:
        name = f"{s['title']} S{e['season']:02}E{e['episode']:02}"
        mine = [x for x in sonarr.get("/episode", seriesId=s["id"]) if (x["seasonNumber"], x["episodeNumber"]) == (e["season"], e["episode"])]
    files = sorted({x["episodeFileId"] for x in mine if x.get("episodeFileId")})
    if not xbmcgui.Dialog().yesno("Delete from disk", f"{name}\n\nSonarr deletes its files ({len(files)}) and stops wanting it, so it won't be downloaded again."):
        return
    # not wanted first: with the files gone a wanted one is missing, and
    # missing is what sonarr goes and looks for
    if mine:
        sonarr.put("/episode/monitor", {"episodeIds": [x["id"] for x in mine], "monitored": False})
    if kind == "season":
        s = sonarr.get(f"/series/{s['id']}")
        for x in s["seasons"]:
            if x["seasonNumber"] == number:
                x["monitored"] = False
        sonarr.put(f"/series/{s['id']}", s)
    if files:
        sonarr.call("DELETE", "/episodefile/bulk", {"episodeFileIds": files})
    # kodi drops what's gone from that show's folder
    rpc("VideoLibrary.Clean", directory=os.path.join(d["file"], ""), showdialogs=False)
    notify(name, "Deleted")
