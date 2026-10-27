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
    (r"smaller than minimum", "слишком маленькая"),
    (r"larger than maximum", "слишком большая"),
    (r"Custom Formats? .*\bHDR\b.* below", "HDR"),
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


# the releases' columns (moviepipe-releases.xml): the button of each, its
# name, how its rows sort, which way first (True: the most first). ties
# keep radarr's or sonarr's order
COLUMNS = {
    101: ("качество", lambda e: e["weight"], True),
    102: ("sdr / hdr", lambda e: e["rank"], False),
    103: ("размер", lambda e: e["size"], True),
    104: ("сиды", lambda e: e["seeders"], True),
    105: ("трекер", lambda e: e["tracker"].casefold(), False),
    106: ("группа", lambda e: (not e["group"], e["group"].casefold()), False),
    107: ("язык", lambda e: (" RU" not in f" {e['language']}", e["language"]), False),
    108: ("возраст", lambda e: e["age"], False),
    109: ("почему ✗", lambda e: e["order"], False),
}
SEARCH = 110


class Releases(Window):
    # enter on a column's name sorts by it, again the other way. those of
    # another film or show stay last
    def onInit(self):
        if self.rows().size():
            return
        self.setProperty("heading", self.heading)
        self.setProperty("hint", self.hint)
        self.sorted, self.most, self.text = 102, False, ""
        self.show()
        self.setFocusId(50)

    def show(self):
        _, key, _ = COLUMNS[self.sorted]
        text = self.text.casefold()
        shown = [e for e in self.entries if text in e["text"]]
        shown.sort(key=key, reverse=self.most)
        shown.sort(key=lambda e: e["other"])
        self.order = shown
        for cid, (name, _, _) in COLUMNS.items():
            arrow = (" ↓" if self.most else " ↑") if cid == self.sorted else ""
            self.setProperty(f"h{cid}", name + arrow)
        self.setProperty("sorted", str(self.sorted))
        self.setProperty(f"h{SEARCH}", f"поиск: {self.text}" if self.text else "поиск")
        self.setProperty("filter", f"«{self.text}»" if self.text else "")
        self.setProperty("empty", "" if shown else "Ничего не нашлось")
        self.rows().reset()
        self.rows().addItems([e["item"] for e in shown])
        self.rows().selectItem(0)

    def onClick(self, control):
        if control in COLUMNS:
            if control == self.sorted:
                self.most = not self.most
            else:
                self.sorted, self.most = control, COLUMNS[control][2]
            self.show()
        elif control == SEARCH:
            self.text = xbmcgui.Dialog().input("Поиск: название, группа, трекер", self.text).strip()
            self.show()
        elif control == 50:
            at = self.rows().getSelectedPosition()
            if 0 <= at < len(self.order):
                self.picked = self.order[at]["release"]
                self.close()


def entry(r, n, other):
    # n: its place in radarr's or sonarr's order, 0 their own pick
    qname = r["quality"]["quality"]["name"]
    range_, rank = dynamic(r["title"], qname)
    rejections = r.get("rejections", []) if r.get("rejected") else []
    tracker = r["indexer"].replace(" (Prowlarr)", "")
    group = r.get("releaseGroup") or ""
    language = " ".join(LANGUAGES.get(x["name"], x["name"][:2].upper()) for x in r.get("languages", []) if x.get("id", 0) > 0)
    li = xbmcgui.ListItem(r["title"])
    li.setProperties(
        {
            "mark": color("✗", GREY) if rejections else "●" if n == 0 else "",
            "why": "; ".join(rejections),
            "whyline": color("; ".join(rejections), AMBER) if rejections else "",
            "reason": color(reason(rejections), AMBER),
            "quality": quality(qname),
            "range": range_,
            "size": gb(r["size"]) if r.get("size") else "—",
            "seeders": str(r.get("seeders") or 0) if r.get("protocol") == "torrent" else "",
            "tracker": tracker,
            "group": group,
            "language": language,
            "age": age(r.get("age")),
        }
    )
    return {
        "release": r,
        "item": li,
        "order": n,
        "other": other,
        "rank": rank,
        "weight": r.get("qualityWeight") or 0,
        "seeders": r.get("seeders") or 0,
        "size": r.get("size") or 0,
        "age": r.get("ageMinutes", r.get("age")) or 0,
        "tracker": tracker,
        "group": group,
        "language": language,
        "text": " ".join((r["title"], group, tracker, qname)).casefold(),
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
        hint=f"enter — скачать    ↑ на названия колонок: сортировка, поиск    ● — {app} взял бы её сам    ✗ — не взял бы    esc — ничего",
        entries=[entry(r, n, r in others) for n, r in enumerate(ranked)],
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
STOPPED = ("pausedDL", "stoppedDL", "pausedUP", "stoppedUP")
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
        "whyline": color("; ".join(problems), AMBER) if problems else "",
        # the row's button, majan's icons: what it does
        "toggle": ("icons/play.png" if torrent["state"] in STOPPED else "icons/pause.png") if torrent else "",
    }


def downloads():
    # [(key, records, its torrent, row)], what didn't answer
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
    rows = []
    for key, records in found.items():
        torrent = torrents.get(key[1].upper())
        rows.append((key, records, torrent, row(key[0], records, torrent)))
    return rows, trouble


class Downloads(Window):
    # right on a row: its button (pause, go on), left: the row again.
    # space (kodi's pause) works the button from either
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
            keys = [key for key, _, _, _ in found]
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
            self.records = {key: records for key, records, _, _ in found}
            self.torrents = {key: torrent for key, _, torrent, _ in found}
            for li, (_, _, _, props) in zip(self.items, found):
                li.setLabel(props.pop("label"))
                li.setProperties(props)
            self.setProperty("trouble", "; ".join(trouble))
            self.setProperty("empty", "" if found or trouble else "Ничего не качается")

    def onAction(self, action):
        a = action.getId()
        if a in (xbmcgui.ACTION_PREVIOUS_MENU, xbmcgui.ACTION_NAV_BACK):
            self.close()
        elif self.getFocusId() != 50:
            return
        elif a == xbmcgui.ACTION_MOVE_RIGHT:
            self.setProperty("onbutton", "1")
        elif a == xbmcgui.ACTION_MOVE_LEFT:
            self.setProperty("onbutton", "")
        elif a in (xbmcgui.ACTION_PAUSE, xbmcgui.ACTION_PLAYER_PLAYPAUSE):
            self.toggle(self.focused())

    def focused(self):
        at = self.rows().getSelectedPosition()
        return self.keys[at] if 0 <= at < len(self.keys) else None

    def toggle(self, key):
        # qbittorrent 5's names, 4's were resume and pause
        torrent = self.torrents.get(key)
        if not torrent:
            return
        try:
            qbittorrent("/torrents/start" if torrent["state"] in STOPPED else "/torrents/stop", {"hashes": torrent["hash"]})
        except Error as e:
            error(e)
        self.refresh()

    def onClick(self, control):
        key = self.focused()
        if control != 50 or key is None:
            return
        if self.getProperty("onbutton"):
            self.toggle(key)
            return
        records = self.records[key]
        torrent = self.torrents.get(key)
        actions = ["Другая раздача", "Убрать загрузку"]
        if torrent:
            actions.insert(0, "Продолжить" if torrent["state"] in STOPPED else "Пауза")
        i = xbmcgui.Dialog().select(name(key[0], records), actions)
        if i < 0:
            return
        if actions[i] in ("Продолжить", "Пауза"):
            self.toggle(key)
            return
        # another: this one to the blocklist, they search again
        another = actions[i] == "Другая раздача"
        try:
            Api(key[0]).call(
                "DELETE",
                "/queue/bulk",
                {"ids": [r["id"] for r in records]},
                removeFromClient="true",
                blocklist="true" if another else "false",
                skipRedownload="false" if another else "true",
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
        torrents={},
        lock=threading.RLock(),
        done=threading.Event(),
    )
    w.doModal()
    w.done.set()
    # a refresh in its thread finishes before the window goes
    with w.lock:
        pass
    del w
