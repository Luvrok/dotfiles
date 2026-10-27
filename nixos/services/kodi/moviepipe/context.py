# "Скачать" and "Выбрать раздачу…" (addon.xml): the film goes to radarr, the
# show to sonarr. download: they search and take the best release
# themselves (arr/setup.py's profile). pick: the trackers' releases in a
# list, the one picked is downloaded; nothing picked, nothing is added
import sys
import time

import xbmcgui

from arr import Api, Error, choose, error, notify, waiting


def movie(tmdb, pick):
    radarr = Api("radarr")
    have = radarr.get("/movie", tmdbId=tmdb)
    added = not have
    if have:
        m = have[0]
    else:
        m = waiting("Radarr", "Ищу фильм…", lambda: radarr.get("/movie/lookup/tmdb", tmdbId=tmdb))
        if m is None:
            return
        # wanted from the day it's announced, the profile keeps cams out
        m.update(radarr.new(), monitored=True, minimumAvailability="announced")
        m["addOptions"] = {"searchForMovie": not pick}
        m = radarr.post("/movie", m)
    title = f"{m['title']} ({m['year']})"
    if pick:
        if choose(radarr, title, movieId=m["id"]) is None and added:
            # radarr would go and find one itself
            radarr.delete(f"/movie/{m['id']}")
        return
    if added:
        notify(title, "Ищу раздачу")
    elif m.get("hasFile"):
        notify(title, "Уже скачан")
    else:
        if not m["monitored"]:
            m["monitored"] = True
            radarr.put(f"/movie/{m['id']}", m)
        radarr.command("MoviesSearch", movieIds=[m["id"]])
        notify(title, "Ищу раздачу")


def episodes(sonarr, series):
    # a show just added gets its episodes a few seconds later
    for _ in range(60):
        found = sonarr.get("/episode", seriesId=series)
        if found:
            return found
        time.sleep(1)
    raise Error("sonarr: у сериала нет серий")


def show(tmdb, kind, season, episode, pick):
    sonarr = Api("sonarr")
    found = waiting("Sonarr", "Ищу сериал…", lambda: sonarr.get("/series/lookup", term=f"tmdb:{tmdb}"))
    if found is None:
        return
    if not found:
        raise Error("sonarr не нашёл сериал")
    s = found[0]
    title = s["title"]

    numbers = [x["seasonNumber"] for x in s["seasons"] if x["seasonNumber"] > 0]
    if kind == "tvshow":
        labels = [f"Сезон {n}" for n in numbers]
        if pick:
            i = xbmcgui.Dialog().select(f"{title}: сезон", labels)
            if i < 0:
                return
            chosen = [numbers[i]]
        else:
            picked = xbmcgui.Dialog().multiselect(f"{title}: сезоны", labels, preselect=list(range(len(numbers))))
            if not picked:
                return
            chosen = [numbers[i] for i in picked]
    else:
        chosen = [season]
    # an episode alone: none of its season
    whole = kind != "episode"

    added = not s.get("id")
    if added:
        for x in s["seasons"]:
            x["monitored"] = whole and x["seasonNumber"] in chosen
        s.update(
            sonarr.new(),
            monitored=True,
            seasonFolder=True,
            seriesType="anime" if "Anime" in s.get("genres", []) else "standard",
        )
        # episodes as their seasons, those searched right away
        s["addOptions"] = {"monitor": "skip", "searchForMissingEpisodes": whole and not pick}
        s = sonarr.post("/series", s)
    else:
        s = sonarr.get(f"/series/{s['id']}")
        wanted = all(x["monitored"] for x in s["seasons"] if x["seasonNumber"] in chosen)
        if (whole and not wanted) or not s["monitored"]:
            for x in s["seasons"]:
                x["monitored"] = x["monitored"] or (whole and x["seasonNumber"] in chosen)
            s["monitored"] = True
            s = sonarr.put(f"/series/{s['id']}", s)

    if not whole:
        name = f"{title} S{season:02}E{episode:02}"
        ep = next((e for e in episodes(sonarr, s["id"]) if (e["seasonNumber"], e["episodeNumber"]) == (season, episode)), None)
        if ep is None:
            raise Error(f"sonarr: нет серии {name}")
        sonarr.put("/episode/monitor", {"episodeIds": [ep["id"]], "monitored": True})
        if pick:
            if choose(sonarr, name, episodeId=ep["id"]) is None and added:
                sonarr.delete(f"/series/{s['id']}")
        else:
            sonarr.command("EpisodeSearch", episodeIds=[ep["id"]])
            notify(name, "Ищу раздачу")
        return

    if pick:
        name = f"{title}, сезон {chosen[0]}"
        episodes(sonarr, s["id"])
        if choose(sonarr, name, seriesId=s["id"], seasonNumber=chosen[0]) is None and added:
            sonarr.delete(f"/series/{s['id']}")
        return
    if not added:
        for n in chosen:
            sonarr.command("SeasonSearch", seriesId=s["id"], seasonNumber=n)
    notify(title, "Ищу раздачи: " + ", ".join(f"сезон {n}" for n in chosen))


def main():
    pick = sys.argv[1] == "pick"
    tag = sys.listitem.getVideoInfoTag()
    kind = tag.getMediaType()
    try:
        if kind == "movie":
            movie(int(tag.getUniqueID("tmdb")), pick)
        elif kind == "tvshow":
            show(int(tag.getUniqueID("tmdb")), kind, None, None, pick)
        else:
            show(int(tag.getUniqueID("tvshow.tmdb")), kind, tag.getSeason(), tag.getEpisode(), pick)
    except Error as e:
        error(e)


main()
