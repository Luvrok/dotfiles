# video add-ons -> Movie pipe: what radarr and sonarr are downloading, how
# far, why one is stuck. enter on one: another release for it (this one
# goes to the blocklist and they search again) or take it away
import sys
import urllib.parse

import xbmc
import xbmcgui
import xbmcplugin

from arr import Api, Error, error, gb

HANDLE = int(sys.argv[1])
QUERY = dict(urllib.parse.parse_qsl(sys.argv[2][1:]))
STATES = {
    "queued": "в очереди",
    "paused": "на паузе",
    "completed": "скачано",
    "delay": "ждёт",
    "failed": "ошибка",
    "warning": "проблема",
}


def downloads():
    # a season in one torrent is a record per episode: one line for it
    out = {}
    for app, include in (
        ("radarr", {"includeMovie": "true"}),
        ("sonarr", {"includeSeries": "true", "includeEpisode": "true"}),
    ):
        try:
            records = Api(app).get("/queue", pageSize=200, **include)["records"]
        except Error as e:
            error(e)
            continue
        for q in records:
            out.setdefault((app, q.get("downloadId") or q["id"]), []).append(q)
    return out


def name(app, records):
    q = records[0]
    if app == "radarr" and "movie" in q:
        return f"{q['movie']['title']} ({q['movie']['year']})"
    if app == "sonarr" and "series" in q and "episode" in q:
        if len(records) > 1:
            seasons = sorted({r["episode"]["seasonNumber"] for r in records})
            return f"{q['series']['title']}, сезон {', '.join(map(str, seasons))} ({len(records)} серий)"
        return f"{q['series']['title']} S{q['episode']['seasonNumber']:02}E{q['episode']['episodeNumber']:02}"
    return q["title"]


def line(q):
    size = q.get("size") or 0
    left = q.get("sizeleft") or 0
    if q.get("trackedDownloadState") in ("importPending", "importing"):
        state = "переносится в библиотеку"
    elif q.get("status") == "downloading":
        state = f"{int(100 * (size - left) / size) if size else 0}%"
        if q.get("timeleft"):
            state += f", осталось {q['timeleft']}"
    else:
        state = STATES.get(q.get("status"), q.get("status", ""))
    text = f"{state} · {gb(size - left)} из {gb(size)}"
    problems = [q["errorMessage"]] if q.get("errorMessage") else []
    problems += [m for s in q.get("statusMessages", []) for m in s.get("messages", [])]
    if problems:
        text += " · " + "; ".join(problems)[:150]
    return text


def listing():
    found = downloads()
    for (app, _), records in found.items():
        li = xbmcgui.ListItem(label=name(app, records), label2=line(records[0]))
        li.getVideoInfoTag().setPlot(line(records[0]) + "\n" + records[0]["title"])
        ids = ",".join(str(r["id"]) for r in records)
        url = f"{sys.argv[0]}?{urllib.parse.urlencode({'app': app, 'ids': ids, 'name': li.getLabel()})}"
        xbmcplugin.addDirectoryItem(HANDLE, url, li, isFolder=False)
    if not found:
        xbmcplugin.addDirectoryItem(HANDLE, "", xbmcgui.ListItem(label="Ничего не качается"), isFolder=False)
    xbmcplugin.endOfDirectory(HANDLE, cacheToDisc=False)


def action():
    i = xbmcgui.Dialog().select(QUERY["name"], ["Другая раздача", "Убрать загрузку"])
    if i < 0:
        return
    try:
        Api(QUERY["app"]).call(
            "DELETE",
            "/queue/bulk",
            {"ids": [int(x) for x in QUERY["ids"].split(",")]},
            removeFromClient="true",
            blocklist="true" if i == 0 else "false",
            skipRedownload="false" if i == 0 else "true",
        )
    except Error as e:
        error(e)
    xbmc.executebuiltin("Container.Refresh")


if "ids" in QUERY:
    action()
else:
    listing()
