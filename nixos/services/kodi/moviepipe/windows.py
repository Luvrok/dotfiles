# the add-on's two windows, majan-like (resources/skins/Default/1080i):
# the releases to pick one of ("Выбрать раздачу…", ./actions.py) and what
# downloads (6, ./default.py). a row: its name, then columns
import os
import re
import threading

import xbmc
import xbmcgui

from arr import HERE, Api, Error, error, gb, notify, qbittorrent, waiting

# 0.png .. 100.png, a bar per 5% (../addons.nix)
BARS = os.path.join(HERE, "resources", "skins", "Default", "media", "bars")
# majan's accent_amber, accent_mint and accent_rose halfway to its grey,
# its text_primary and text_tertiary
AMBER = "ffc69e53"
GREEN = "ff65b48e"
ROSE = "ffc67488"
WHITE = "ffecebe7"
GREY = "ff8d8b85"
LANGUAGES = {
    "Russian": "RU",
    "English": "EN",
    "Ukrainian": "UK",
    "German": "DE",
    "French": "FR",
    "Spanish": "ES",
    "Italian": "IT",
    "Japanese": "JA",
    "Korean": "KO",
    "Chinese": "ZH",
}


def color(text, argb):
    return f"[COLOR {argb}]{text}[/COLOR]"


def dynamic(title, qname):
    # sdr or hdr as the title says, and its place in "сначала SDR": "DV"
    # alone is dolby vision with no hdr10 under it. a title with neither:
    # sdr up to 1080p (a blu-ray, so a bdrip, is sdr; hdr is uhd
    # blu-ray's), a 2160p one may be either
    t = re.sub(r"[._\[\](),/]", " ", title)
    found = []
    if re.search(r"\b(dv|dovi|dolby ?vision)\b", t, re.I):
        found.append("DV")
    if re.search(r"\bhdr10(\+|p\b|plus\b)", t, re.I):
        found.append("HDR10+")
    elif re.search(r"\bhdr10\b", t, re.I):
        found.append("HDR10")
    elif re.search(r"\bhdr\b", t, re.I):
        found.append("HDR")
    if re.search(r"\bhlg\b", t, re.I):
        found.append("HLG")
    if found:
        return color("+".join(found), AMBER), 2
    if re.search(r"\bsdr\b", t, re.I) or "2160" not in qname:
        return color("SDR", GREEN), 0
    return color("HDR?", AMBER), 1


def quality(name):
    # radarr's and sonarr's names as on the trackers: a bdrip up to 1080p,
    # the profile's best, stands out
    shown = re.sub(r"-(\d+p)$", r" \1", re.sub(r"^Bluray-", "BDRip-", name.replace("WEBDL-", "WEB-DL-")))
    if name in ("Bluray-1080p", "Bluray-720p"):
        return color(shown, WHITE)
    return shown


# why radarr or sonarr wouldn't take a release, short
REASONS = [
    (r"not wanted in profile", "качество не из профиля"),
    (r"^Unknown (Movie|Series)", "не узнал фильм"),
    (r"^Wrong ", "другой фильм"),
    (r"Not enough seeders", "мало сидов"),
    (r"blocklisted", "в чёрном списке"),
    (r"in queue", "уже качается"),
    (r"^Existing file", "уже скачан"),
    (r"grab event in history", "уже брал раньше"),
    (r"considered available", "ещё не вышел"),
    (r"not monitored", "не отслеживается"),
    (r"^Indexer .* blocked", "трекер на паузе"),
    (r"larger than maximum|smaller than minimum", "не тот размер"),
    (r"Custom Formats? .* below", "низкая оценка"),
    (r"is wanted, but found", "не тот язык"),
    (r"Hardcode subs", "вшитые субтитры"),
    (r"^Sample", "сэмпл"),
    (r"^Raw ", "образ диска"),
    (r"terms", "фильтр слов"),
    (r"minutes old", "слишком свежая"),
]


def reason(rejections):
    out = []
    for text in rejections:
        short = next((ru for rx, ru in REASONS if re.search(rx, text, re.I)), text[:40])
        if short not in out:
            out.append(short)
    return ", ".join(out)


def age(days):
    if days is None:
        return ""
    if days < 1:
        return "сегодня"
    if days < 60:
        return f"{days} дн"
    if days < 730:
        return f"{days // 30} мес"
    return f"{days // 365} г"


class Window(xbmcgui.WindowXMLDialog):
    def rows(self):
        return self.getControl(50)


def window(cls, xml, **attrs):
    w = cls(xml, HERE, "Default", "1080i")
    for k, v in attrs.items():
        setattr(w, k, v)
    return w


class Releases(Window):
    # left and right: the next sort. those of another film or show stay
    # last in each
    def onInit(self):
        if self.rows().size():
            return
        self.setProperty("heading", self.heading)
        self.setProperty("hint", self.hint)
        self.show(0)
        self.setFocusId(50)

    def show(self, mode):
        self.mode = mode % len(self.sorts)
        name, key = self.sorts[self.mode]
        self.order = sorted(self.entries, key=lambda e: (e["other"], key(e)))
        self.setProperty("sort", f"← {name} →")
        self.rows().reset()
        self.rows().addItems([e["item"] for e in self.order])
        self.rows().selectItem(0)

    def onAction(self, action):
        a = action.getId()
        if a in (xbmcgui.ACTION_PREVIOUS_MENU, xbmcgui.ACTION_NAV_BACK):
            self.close()
        elif a in (xbmcgui.ACTION_MOVE_LEFT, xbmcgui.ACTION_MOVE_RIGHT) and self.getFocusId() == 50:
            self.show(self.mode + (1 if a == xbmcgui.ACTION_MOVE_RIGHT else -1))

    def onClick(self, control):
        at = self.rows().getSelectedPosition()
        if control == 50 and 0 <= at < len(self.order):
            self.picked = self.order[at]["release"]
            self.close()


def entry(r, n, other):
    # n: its place in radarr's or sonarr's order, 0 their own pick
    qname = r["quality"]["quality"]["name"]
    range_, rank = dynamic(r["title"], qname)
    rejections = r.get("rejections", []) if r.get("rejected") else []
    li = xbmcgui.ListItem(r["title"])
    li.setProperties(
        {
            "mark": color("✗", GREY) if rejections else "●" if n == 0 else "",
            "why": "; ".join(rejections),
            "reason": color(reason(rejections), AMBER),
            "quality": quality(qname),
            "range": range_,
            "size": gb(r["size"]) if r.get("size") else "—",
            "seeders": str(r.get("seeders") or 0) if r.get("protocol") == "torrent" else "",
            "tracker": r["indexer"].replace(" (Prowlarr)", ""),
            "group": r.get("releaseGroup") or "",
            "language": " ".join(LANGUAGES.get(x["name"], x["name"][:2].upper()) for x in r.get("languages", []) if x.get("id", 0) > 0),
            "age": age(r.get("age")),
        }
    )
    return {
        "release": r,
        "item": li,
        "order": n,
        "rank": rank,
        "other": other,
        "seeders": r.get("seeders") or 0,
        "size": r.get("size") or 0,
        "age": r.get("ageMinutes", r.get("age")) or 0,
    }


def choose(api, title, **query):
    # the releases the trackers have, sdr first, then as radarr or sonarr
    # rank them: those they'd take first, in their order (quality, their
    # score, the tracker's priority, seeders), the first the one they'd
    # download themselves. the ones they took for another film or show
    # last (the trackers are searched with no year, ../../arr/setup.py).
    # the one picked is downloaded even when they'd reject it, for this
    # film or show (query's ids)
    found = waiting(title, "Ищу раздачи на трекерах…", lambda: api.get("/release", timeout=300, **query))
    if found is None:
        return None
    if not found:
        notify(title, "Раздач нет")
        return None
    mapped = [r for r in found if r.get("mappedMovieId", r.get("mappedSeriesId")) is not None]
    others = [r for r in found if r not in mapped]
    ranked = [r for r in mapped if not r.get("rejected")] + [r for r in mapped if r.get("rejected")] + others
    app = api.app.capitalize()
    w = window(
        Releases,
        "moviepipe-releases.xml",
        heading=f"{title}: раздачи",
        hint=f"enter — скачать    ← → — сортировка    ● — {app} взял бы её сам    ✗ — не взял бы, почему — справа    esc — ничего",
        entries=[entry(r, n, r in others) for n, r in enumerate(ranked)],
        sorts=[
            ("сначала SDR", lambda e: (e["rank"], e["order"])),
            (f"как {app}", lambda e: e["order"]),
            ("по сидам", lambda e: -e["seeders"]),
            ("по размеру", lambda e: -e["size"]),
            ("по свежести", lambda e: e["age"]),
        ],
        picked=None,
    )
    w.doModal()
    r = w.picked
    del w
    if r is None:
        return None
    ids = {k: v for k, v in query.items() if k in ("movieId", "seriesId", "episodeId")}
    api.post("/release", {"guid": r["guid"], "indexerId": r["indexerId"], **ids}, timeout=120)
    notify(title, f"Качаю: {r['quality']['quality']['name']}, {gb(r['size'])}")
    return r


# what downloads, every 2 s while the window is open: radarr's and
# sonarr's queues, qbittorrent's numbers for their torrents. a season in
# one torrent is a record per episode in sonarr's queue, a row here
QBT_STATES = {
    "downloading": "качается",
    "forcedDL": "качается",
    "metaDL": "метаданные",
    "forcedMetaDL": "метаданные",
    "stalledDL": color("нет пиров", AMBER),
    "queuedDL": "в очереди",
    "pausedDL": "на паузе",
    "stoppedDL": "на паузе",
    "checkingDL": "проверка",
    "checkingResumeData": "проверка",
    "moving": "переносится",
    "error": color("ошибка", ROSE),
    "missingFiles": color("нет файлов", ROSE),
}
LOADING = ("downloading", "forcedDL", "stalledDL", "metaDL", "forcedMetaDL")
ARR_STATES = {
    "queued": "в очереди",
    "paused": "на паузе",
    "delay": "ждёт",
    "downloading": "качается",
    "completed": color("скачано", GREEN),
    "warning": color("проблема", AMBER),
    "failed": color("ошибка", ROSE),
    "downloadClientUnavailable": color("qbittorrent не отвечает", ROSE),
}


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


def duration(seconds):
    if seconds is None or seconds >= 8640000:
        return "∞"
    if seconds < 60:
        return f"{seconds} с"
    if seconds < 3600:
        return f"{seconds // 60} мин"
    if seconds < 86400:
        return f"{seconds // 3600} ч {seconds % 3600 // 60:02} мин"
    return f"{seconds // 86400} д {seconds % 86400 // 3600} ч"


def timeleft(text):
    # servarr's "[d.]hh:mm:ss"
    m = re.match(r"(?:(\d+)\.)?(\d+):(\d+):(\d+)", text or "")
    if not m:
        return None
    d, h, mi, s = (int(x or 0) for x in m.groups())
    return ((d * 24 + h) * 60 + mi) * 60 + s


def speed(rate):
    if rate >= 1024**2:
        return f"{rate / 1024 ** 2:.1f} МБ/с"
    return f"{rate // 1024} КБ/с"


def row(app, records, torrent):
    q = records[0]
    size = q.get("size") or 0
    left = q.get("sizeleft") or 0
    seconds = timeleft(q.get("timeleft"))
    rate = seeders = ""
    if torrent:
        size = torrent["size"] or size
        left = size - int(torrent["progress"] * size)
        seconds = torrent["eta"]
        state = QBT_STATES.get(torrent["state"], color("скачано", GREEN))
        if torrent["state"] in LOADING:
            rate = speed(torrent["dlspeed"])
            # connected, of the swarm's
            seeders = f"{torrent['num_seeds']} ({max(torrent['num_complete'], 0)})"
    else:
        state = ARR_STATES.get(q.get("status"), q.get("status", ""))
    tracked = q.get("trackedDownloadState")
    if tracked in ("importPending", "importing"):
        state = color("в библиотеку", GREEN)
    elif tracked == "importBlocked":
        state = color("не переносится", AMBER)
    elif tracked in ("failedPending", "failed"):
        state = color("ошибка", ROSE)
    problems = [q["errorMessage"]] if q.get("errorMessage") else []
    problems += [m for s in q.get("statusMessages", []) for m in s.get("messages", [])]
    percent = int(100 * (size - left) / size) if size else 0
    qname = q["quality"]["quality"]["name"]
    return {
        "label": name(app, records),
        "mark": "!" if problems else "",
        "state": state,
        "bar": os.path.join(BARS, f"{percent // 5 * 5}.png"),
        "percent": f"{percent}%",
        "done": f"{gb(size - left)} из {gb(size)}",
        "speed": rate,
        "seeders": seeders,
        "eta": duration(seconds) if left else "",
        "quality": quality(qname),
        "range": dynamic(q["title"], qname)[0],
        "tracker": (q.get("indexer") or "").replace(" (Prowlarr)", ""),
        "release": q["title"],
        "why": "; ".join(problems),
    }


def downloads():
    # [(key, records, row)], what didn't answer
    found, trouble = {}, []
    for app, include in (
        ("radarr", {"includeMovie": "true"}),
        ("sonarr", {"includeSeries": "true", "includeEpisode": "true"}),
    ):
        try:
            records = Api(app).get("/queue", timeout=10, pageSize=200, **include)["records"]
        except Error as e:
            trouble.append(str(e))
            continue
        for q in records:
            found.setdefault((app, q.get("downloadId") or str(q["id"])), []).append(q)
    torrents = {}
    if found:
        try:
            hashes = "|".join(k.lower() for _, k in found)
            torrents = {t["hash"].upper(): t for t in qbittorrent("/torrents/info", hashes=hashes)}
        except Error as e:
            trouble.append(str(e))
    rows = [(key, records, row(key[0], records, torrents.get(key[1].upper()))) for key, records in found.items()]
    return rows, trouble


class Downloads(Window):
    def onInit(self):
        if self.started:
            return
        self.started = True
        self.refresh()
        self.setFocusId(50)
        threading.Thread(target=self.loop, daemon=True).start()

    def loop(self):
        monitor = xbmc.Monitor()
        while not self.done.wait(2) and not monitor.abortRequested():
            try:
                self.refresh()
            except RuntimeError:
                return

    def refresh(self):
        with self.lock:
            found, trouble = downloads()
            if self.done.is_set():
                return
            keys = [key for key, _, _ in found]
            control = self.rows()
            if keys != self.keys:
                # one came or went: the list again, the focus where it was
                at = control.getSelectedPosition()
                at = self.keys[at] if 0 <= at < len(self.keys) else None
                control.reset()
                self.items = [xbmcgui.ListItem() for _ in found]
                control.addItems(self.items)
                if at in keys:
                    control.selectItem(keys.index(at))
                self.keys = keys
            self.records = {key: records for key, records, _ in found}
            for li, (_, _, props) in zip(self.items, found):
                li.setLabel(props.pop("label"))
                li.setProperties(props)
            self.setProperty("trouble", "; ".join(trouble))
            self.setProperty("empty", "" if found or trouble else "Ничего не качается")

    def onClick(self, control):
        at = self.rows().getSelectedPosition()
        if control != 50 or not 0 <= at < len(self.keys):
            return
        key = self.keys[at]
        records = self.records[key]
        i = xbmcgui.Dialog().select(name(key[0], records), ["Другая раздача", "Убрать загрузку"])
        if i < 0:
            return
        try:
            # another: this one to the blocklist, they search again
            Api(key[0]).call(
                "DELETE",
                "/queue/bulk",
                {"ids": [r["id"] for r in records]},
                removeFromClient="true",
                blocklist="true" if i == 0 else "false",
                skipRedownload="false" if i == 0 else "true",
            )
        except Error as e:
            error(e)
        self.refresh()


def show_downloads():
    w = window(
        Downloads,
        "moviepipe-downloads.xml",
        started=False,
        keys=[],
        items=[],
        records={},
        lock=threading.RLock(),
        done=threading.Event(),
    )
    w.doModal()
    w.done.set()
    # a refresh in its thread finishes before the window goes
    with w.lock:
        pass
    del w
