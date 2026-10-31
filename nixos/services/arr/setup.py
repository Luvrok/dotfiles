# what radarr, sonarr, prowlarr and bazarr are told through their apis:
# qbittorrent, the library's folders, the trackers, the quality, the
# subtitles. arr-setup runs it on every switch and boot (./default.nix):
# what it sets it puts back, the rest made in their web uis stays. a step
# that fails (the disk not there, an app down) doesn't stop the others,
# the next run tries again. setup.py CONFIG.json
import json
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

import yaml

C = json.load(open(sys.argv[1]))
# the services are on 127.0.0.1, never through a proxy from the environment
urllib.request.install_opener(urllib.request.build_opener(urllib.request.ProxyHandler({})))


def log(*args):
    print(*args, flush=True)


def key(app):
    with open(f"{C['keys']}/{app}") as f:
        return f.read().strip()


def secrets():
    # secrets/arr.yaml, whatever of it there is
    try:
        with open(C["secrets"]) as f:
            return yaml.safe_load(f) or {}
    except (TypeError, FileNotFoundError):
        return {}


class Api:
    def __init__(self, name, port, path, header="X-Api-Key"):
        self.name = name
        self.base = f"http://127.0.0.1:{port}/api{path}"
        self.headers = {header: key(name)}

    def call(self, method, path, body=None, form=None):
        headers = dict(self.headers)
        data = None
        if body is not None:
            data = json.dumps(body).encode()
            headers["Content-Type"] = "application/json"
        if form is not None:
            data = urllib.parse.urlencode(form, doseq=True).encode()
            headers["Content-Type"] = "application/x-www-form-urlencoded"
        req = urllib.request.Request(self.base + path, data, headers, method=method)
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                raw = r.read()
        except urllib.error.HTTPError as e:
            text = e.read().decode(errors="replace")[:500]
            raise RuntimeError(f"{self.name}: {method} {path}: {e.code} {text}") from None
        return json.loads(raw) if raw.strip() else None

    def get(self, path):
        return self.call("GET", path)

    def put(self, path, body):
        return self.call("PUT", path, body)

    def post(self, path, body=None, form=None):
        return self.call("POST", path, body, form)

    def wait(self):
        # radarr migrates its database on the first start, a minute or so
        for _ in range(150):
            try:
                return self.get("/system/status")
            except (OSError, RuntimeError):
                time.sleep(2)
        raise RuntimeError(f"{self.name} isn't up")


def provider(api, path, name, match, fields, **attrs):
    # a download client, tracker, app or proxy called name: the one there,
    # or a new one from the schema. fields are its settings by their names.
    # forceSave: saved even when its test fails (a tracker down, a login
    # it doesn't take). a new one is tested anyway while it's on: made off,
    # then turned on
    item = next((x for x in api.get(path) if x["name"] == name), None)
    if item is None:
        item = next((x for x in api.get(path + "/schema") if match(x)), None)
    if item is None:
        raise RuntimeError(f"{api.name} has no {name} to make")
    item = dict(item, name=name, **attrs)
    item.pop("presets", None)
    have = {f["name"]: f for f in item["fields"]}
    for k, v in fields.items():
        if k not in have:
            raise RuntimeError(f"{api.name}: {name} has no {k}")
        have[k]["value"] = v
    if "id" not in item:
        enable = item.get("enable")
        item = api.post(f"{path}?forceSave=true", dict(item, enable=False) if enable else item)
        if not enable:
            return item
        item["enable"] = True
    return api.put(f"{path}/{item['id']}?forceSave=true", item)


def impl(implementation):
    return lambda x: x["implementation"] == implementation


def updated(api, path, **values):
    # a settings page, saved when something differs
    page = api.get(path)
    if any(page.get(k) != v for k, v in values.items()):
        api.put(path, dict(page, **values))


def proxy(api, on=True):
    # the provider's blocks: xray's mixed inbound (hosts/barnard/xray.nix)
    # when ./default.nix turns it on, 127.0.0.1 and the lan go straight.
    # prowlarr's off: its trackers go straight or through xray each
    # (straight below)
    p = C["proxy"] if on else None
    updated(
        api,
        "/config/host",
        proxyEnabled=p is not None,
        proxyType="http",
        proxyHostname=p["host"] if p else "",
        proxyPort=p["port"] if p else 8080,
        proxyBypassFilter="",
        proxyBypassLocalAddresses=True,
    )


# prowlarr's trackers, and flaresolverr for them, straight: through
# xray a connection takes some 30 s, flaresolverr ran out of its 60 on
# cloudflare's checks and prowlarr turned the tracker off. straight it
# solves uindex's in 11 s, 1337x's in 32. a tracker whose test fails
# straight goes through xray (an indexer proxy, by its tag): one behind
# cloudflare fails there too (flaresolverr's cookie is for this ip), the
# log says so. prowlarr's own servers answer 403 straight: no new tracker
# definitions without xray, the ones it has stay
def straight(api, xray):
    for item in api.get("/indexer"):
        if not item["enable"] or "rutracker" in item["definitionName"]:
            continue
        item["tags"] = [t for t in item["tags"] if t != xray]
        api.put(f"/indexer/{item['id']}?forceSave=true", item)
        try:
            api.post("/indexer/test", item)
            log(f"prowlarr: {item['name']} straight")
            continue
        except Exception as e:  # noqa: BLE001 - a timeout too: through xray
            # prowlarr's reasons are json, their messages on one line
            why = re.findall(r'"errorMessage": "([^"]*)"', str(e)) or [str(e)]
        item["tags"].append(xray)
        api.put(f"/indexer/{item['id']}?forceSave=true", item)
        log(f"prowlarr: {item['name']} through xray: {' / '.join(why)[:300]}")


def command(api, name):
    # a command of theirs, waited for
    c = api.post("/command", {"name": name})
    for _ in range(150):
        c = api.get(f"/command/{c['id']}")
        if c["status"] not in ("queued", "started"):
            return c
        time.sleep(2)
    return c


def tag(api, label):
    tags = {t["label"]: t["id"] for t in api.get("/tag")}
    return tags.get(label) or api.post("/tag", {"label": label})["id"]


# the qualities a release may be, the best last, the profile in this
# order: a bdrip 1080p, then 4k (not hdr, below), then a web-dl 1080p,
# then 720p. their groups taken apart: a webrip (a stream recorded and
# encoded again) isn't, a web-dl (the stream's own file) is. a 720p gets
# replaced by a 1080p or 4k once there is one (cutoff), a web-dl 1080p or
# 4k stays
QUALITIES = {
    "radarr": ["WEBDL-720p", "Bluray-720p", "WEBDL-1080p", "WEBDL-2160p", "Remux-2160p", "Bluray-2160p", "Bluray-1080p"],
    "sonarr": [
        "WEBDL-720p",
        "Bluray-720p",
        "HDTV-1080p",
        "WEBDL-1080p",
        "WEBDL-2160p",
        "Bluray-2160p Remux",
        "Bluray-2160p",
        "Bluray-1080p",
    ],
}
CUTOFF = "WEBDL-1080p"
PROFILE = "BDRip 1080p"
# the least a release may be, MB a minute of the film or episode: below
# are the encodes that show on a big screen (a 2 GB 1080p film). a web-dl
# 1080p is 30 to 60, a 2 h film at 25 is 3.6 GB
MIN_SIZE = {"720p": 12, "1080p": 25, "2160p": 60}
# custom formats: name, its kind, what it looks for, its score. among
# equal qualities a russian dub wins (rutracker's titles get "RUS",
# below), no upgrade for it alone: cutoffFormatScore 0. hdr, as its title
# says it, never: below minFormatScore 0. a 4k title that says nothing
# may still be hdr (kodi's add-on shows "HDR?")
FORMATS = [
    ("Russian", "LanguageSpecification", 11, 10),
    ("HDR", "ReleaseTitleSpecification", r"\b(HDR|HDR10|HDR10Plus|HDR10P|DV|DoVi|HLG)\b|Dolby[ ._-]?Vision", -10000),
]


def custom_format(api, name, implementation, value):
    have = next((f for f in api.get("/customformat") if f["name"] == name), None)
    spec = next(s for s in api.get("/customformat/schema") if s["implementation"] == implementation)
    spec = dict(spec, name=name, negate=False, required=False)
    spec.pop("presets", None)
    for f in spec["fields"]:
        if f["name"] == "value":
            f["value"] = value
    body = {"name": name, "includeCustomFormatWhenRenaming": False, "specifications": [spec]}
    if have is None:
        api.post("/customformat", body)
    else:
        api.put(f"/customformat/{have['id']}", dict(body, id=have["id"]))


def profile(api, app):
    for name, implementation, value, _ in FORMATS:
        custom_format(api, name, implementation, value)
    formats = api.get("/customformat")
    wanted = {name: score for name, _, _, score in FORMATS}

    p = next((p for p in api.get("/qualityprofile") if p["name"] == PROFILE), None)
    if p is None:
        p = api.get("/qualityprofile/schema")
    allowed = QUALITIES[app]
    # no groups, a quality each; the rank is the order, the best last: the
    # rest, then the allowed ones
    items = [
        {"quality": q["quality"], "items": [], "allowed": q["quality"]["name"] in allowed}
        for item in p["items"]
        for q in (item["items"] or [item])
    ]
    rank = lambda item: allowed.index(item["quality"]["name"]) if item["allowed"] else -1
    p["items"] = sorted(items, key=rank)
    cutoff = next(item["quality"]["id"] for item in items if item["quality"]["name"] == CUTOFF)
    scores = {f["format"]: f["score"] for f in p.get("formatItems", [])}
    p.update(
        name=PROFILE,
        upgradeAllowed=True,
        cutoff=cutoff,
        minFormatScore=0,
        cutoffFormatScore=0,
        minUpgradeFormatScore=1,
        formatItems=[
            {
                "format": f["id"],
                "name": f["name"],
                "score": wanted.get(f["name"], scores.get(f["id"], 0)),
            }
            for f in formats
        ],
    )
    if app == "radarr":
        # a release in any language, the default is the film's original one
        p["language"] = {"id": -1, "name": "Any"}
    if "id" in p:
        api.put(f"/qualityprofile/{p['id']}", p)
    else:
        api.post("/qualityprofile", p)


def sizes(api, app):
    changed = []
    for d in api.get("/qualitydefinition"):
        name = d["quality"]["name"]
        least = next((n for r, n in MIN_SIZE.items() if r in name), None)
        if name in QUALITIES[app] and least is not None and d.get("minSize") != least:
            changed.append(dict(d, minSize=least))
    if changed:
        api.put("/qualitydefinition/update", changed)


def servarr(app):
    movies = app == "radarr"
    api = Api(app, C[app], "/v3")
    api.wait()
    steps = {
        # first: the rest may need it
        "proxy": lambda: proxy(api),
        # qbittorrent, in its own folder of downloads (the category). a
        # torrent goes away once it seeded enough (qbittorrent's share
        # limits), its files stay in the library as hardlinks
        "qbittorrent": lambda: provider(
            api,
            "/downloadclient",
            "qBittorrent",
            impl("QBittorrent"),
            {
                "host": "127.0.0.1",
                "port": C["qbittorrent"],
                ("movieCategory" if movies else "tvCategory"): app,
            },
            enable=True,
            priority=1,
            removeCompletedDownloads=True,
            removeFailedDownloads=True,
        ),
        "library": lambda: (
            None
            if any(r["path"].rstrip("/") == C["library"][app] for r in api.get("/rootfolder"))
            else api.post("/rootfolder", {"path": C["library"][app]})
        ),
        "profile": lambda: profile(api, app),
        "sizes": lambda: sizes(api, app),
        # names kodi finds on tmdb with no search: the id in {tmdb-...}
        "names": lambda: updated(
            api,
            "/config/naming",
            **(
                {
                    "renameMovies": True,
                    "movieFolderFormat": "{Movie Title} ({Release Year}) {tmdb-{TmdbId}}",
                    "standardMovieFormat": "{Movie Title} ({Release Year}) {tmdb-{TmdbId}} [{Quality Full}]",
                }
                if movies
                else {
                    "renameEpisodes": True,
                    "seriesFolderFormat": "{Series TitleYear} {tmdb-{TmdbId}}",
                    "seasonFolderFormat": "Season {season:00}",
                    "standardEpisodeFormat": "{Series Title} - S{season:00}E{episode:00} - {Episode CleanTitle} [{Quality Full}]",
                    "dailyEpisodeFormat": "{Series Title} - {Air-Date} - {Episode CleanTitle} [{Quality Full}]",
                    "animeEpisodeFormat": "{Series Title} - S{season:00}E{episode:00} - {absolute:000} - {Episode CleanTitle} [{Quality Full}]",
                }
            ),
        ),
        # subtitles that come in the torrent go next to the video too
        "extras": lambda: updated(api, "/config/mediamanagement", importExtraFiles=True, extraFileExtensions="srt,ass,ssa"),
    }
    return run(app, steps)


def prowlarr(sec):
    api = Api("prowlarr", C["prowlarr"], "/v1")
    api.wait()
    flaresolverr = tag(api, "flaresolverr")

    # uindex, thepiratebay and 1337x are cardigann definitions, prowlarr
    # gets them from indexers.prowlarr.com: its list on every look, their
    # files when it starts. it started before the proxy was set: again
    def definitions():
        wanted = {"uindex", "thepiratebay", "1337x"} | ({"rutracker-proxy"} if sec.get("rutracker_username") else set())
        have = lambda: {x["definitionName"] for x in api.get("/indexer/schema")}
        if wanted - have():
            command(api, "IndexerDefinitionUpdate")
        if C["proxy"] and wanted - have():
            # straight indexers.prowlarr.com answers 403: through xray for it
            proxy(api)
            try:
                command(api, "IndexerDefinitionUpdate")
            finally:
                proxy(api, on=False)
        if missing := wanted - have():
            raise RuntimeError(
                f"no definitions of {', '.join(sorted(missing))}: indexers.prowlarr.com doesn't answer"
                " (journalctl -u prowlarr, useProxy in nixos/services/arr/default.nix)"
            )

    xray = tag(api, "xray")
    steps = {
        "proxy": lambda: proxy(api, on=False),
        "definitions": definitions,
        # xray for a tracker that doesn't answer straight
        "xray": lambda: C["proxy"]
        and provider(
            api,
            "/indexerProxy",
            "xray",
            impl("Http"),
            {"host": C["proxy"]["host"], "port": C["proxy"]["port"]},
            tags=[xray],
        ),
        # cloudflare's checks for 1337x and uindex: a chromium
        # passes them, a tracker with the tag gets its cookies. prowlarr
        # tests it with prowlarr.servarr.com (journalctl -u flaresolverr
        # when it fails), through the proxy too
        "flaresolverr": lambda: provider(
            api,
            "/indexerProxy",
            "FlareSolverr",
            impl("FlareSolverr"),
            {"host": f"http://127.0.0.1:{C['flaresolverr']}/", "requestTimeout": 60},
            tags=[flaresolverr],
        ),
        # every tracker is synced to both (fullSync), their searches go
        # through prowlarr
        **{
            app: (
                lambda app=app: provider(
                    api,
                    "/applications",
                    app.capitalize(),
                    impl(app.capitalize()),
                    {
                        "prowlarrUrl": f"http://127.0.0.1:{C['prowlarr']}",
                        "baseUrl": f"http://127.0.0.1:{C[app]}",
                        "apiKey": key(app),
                    },
                    syncLevel="fullSync",
                    enable=True,
                )
            )
            for app in ("radarr", "sonarr")
        },
    }

    # the trackers by priority, 1 first: of two equal releases radarr and
    # sonarr take the one of the tracker before: rutracker, uindex, the
    # pirate bay, 1337x, magnet or not. a .torrent has its files already, a
    # magnet gets them from peers: no udp here, no dht, only the http
    # trackers qbittorrent adds to it (./default.nix). so the torrent url
    # wherever there is one
    def tracker(name, definition, priority, fields=None, tags=(), enable=True):
        return lambda: provider(
            api,
            "/indexer",
            name,
            lambda x: x["definitionName"] == definition,
            {"torrentBaseSettings.preferMagnetUrl": False, **(fields or {})},
            enable=enable,
            priority=priority,
            appProfileId=1,
            tags=list(tags),
        )

    if sec.get("rutracker_username"):
        # through rutracker-proxy (./default.nix), cloudflare is its job.
        # titles are russian / english [year, country, genre, quality]: the
        # russian name out, "RUS" when there's a russian track. a captcha on
        # login shows in prowlarr: indexers -> RuTracker -> test
        steps["rutracker"] = tracker(
            "RuTracker",
            "rutracker-proxy",
            1,
            {
                "username": sec["rutracker_username"],
                "password": str(sec.get("rutracker_password", "")),
                "stripcyrillic": True,
                "addrus": True,
            },
        )
    else:
        log("prowlarr: no rutracker_username in secrets/arr.yaml, rutracker skipped")
    # prowlarr's own rutracker: cloudflare doesn't let it in
    steps["old rutracker"] = lambda: [
        api.call("DELETE", f"/indexer/{x['id']}") for x in api.get("/indexer") if x["implementation"] == "RuTracker"
    ]
    # magnets only, no .torrent on the site
    steps["uindex"] = tracker("Uindex", "uindex", 2, tags=[flaresolverr])
    steps["thepiratebay"] = tracker("The Pirate Bay", "thepiratebay", 3)
    # primary and fallback to itorrents' .torrent, the definition's default
    # is the magnet
    steps["1337x"] = tracker(
        "1337x",
        "1337x",
        4,
        {
            "primarydownloadlink": 0,
            "fallbackdownloadlink": 0,
        },
        tags=[flaresolverr],
    )
    steps["straight"] = lambda: C["proxy"] and straight(api, xray)
    # waited for: radarr's trackers are there for years() after
    steps["sync"] = lambda: command(api, "ApplicationIndexerSync")
    return run("prowlarr", steps)


def years():
    # a film's year on a tracker is often the one it was first shown in (a
    # festival, imdb's year), tmdb's the one it came out in, and radarr
    # asks for "title year" with tmdb's. its title alone: radarr takes a
    # release of either year (its secondary year, the premiere's) and
    # throws away the films of the same name. prowlarr's sync keeps the
    # field once it's set
    api = Api("radarr", C["radarr"], "/v3")
    for x in api.get("/indexer"):
        field = next((f for f in x["fields"] if f["name"] == "removeYear"), None)
        if field is not None and field.get("value") is not True:
            field["value"] = True
            api.put(f"/indexer/{x['id']}?forceSave=true", x)


def bazarr(sec):
    api = Api("bazarr", C["bazarr"], "", header="X-API-KEY")
    api.wait()
    # russian and english for everything, profile 1 (./default.nix makes
    # it the default). russian is skipped when the video has a russian dub
    # (audio_exclude). an english one goes to ./subtitles.py, that makes it
    # russian when there's still none
    item = {"audio_exclude": "False", "audio_only_include": "False", "hi": "False", "forced": "False"}
    languages = {
        "profileId": 1,
        "name": "Russian, English",
        "cutoff": None,
        "items": [
            dict(item, id=1, language="ru", audio_exclude="True"),
            dict(item, id=2, language="en"),
        ],
        "mustContain": [],
        "mustNotContain": [],
        "originalFormat": False,
        "tag": None,
    }
    # embeddedsubtitles takes those in the video out next to it: bazarr
    # counts only files (use_embedded_subs off), so an english track inside
    # gets translated too. opensubtitles.com has most of the russian ones,
    # it needs its free account
    providers = ["embeddedsubtitles", "yifysubtitles", "tvsubtitles"]
    form = {"languages-enabled": ["ru", "en"], "languages-profiles": json.dumps([languages])}
    if sec.get("opensubtitles_username"):
        providers.insert(0, "opensubtitlescom")
        form["settings-opensubtitlescom-username"] = str(sec["opensubtitles_username"])
        form["settings-opensubtitlescom-password"] = str(sec.get("opensubtitles_password", ""))
    else:
        log("bazarr: no opensubtitles_username in secrets/arr.yaml, opensubtitles.com skipped")
    form["settings-general-enabled_providers"] = providers
    return run("bazarr", {"subtitles": lambda: api.post("/system/settings", form=form)})


def run(app, steps):
    failed = 0
    for name, step in steps.items():
        try:
            step()
            log(f"{app}: {name}")
        except Exception as e:
            failed += 1
            log(f"{app}: {name} failed: {e or type(e).__name__}")
    return failed


sec = secrets()
failed = 0
for setup in (
    lambda: servarr("radarr"),
    lambda: servarr("sonarr"),
    lambda: prowlarr(sec),
    lambda: run("radarr", {"years": years}),
    lambda: bazarr(sec),
):
    try:
        failed += setup()
    except Exception as e:
        failed += 1
        log(e)
sys.exit(1 if failed else 0)
