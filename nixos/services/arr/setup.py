# what radarr, sonarr, prowlarr and bazarr are told through their apis:
# qbittorrent, the library's folders, the trackers, the quality, the
# subtitles. arr-setup runs it on every switch and boot (./default.nix):
# what it sets it puts back, the rest made in their web uis stays. a step
# that fails (the disk not there, an app down) doesn't stop the others,
# the next run tries again. setup.py CONFIG.json
import json
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


def proxy(api):
    # the provider's blocks: xray's mixed inbound (hosts/barnard/xray.nix)
    # when ./default.nix turns it on, 127.0.0.1, the lan and its direct
    # hosts go straight
    p = C["proxy"]
    updated(
        api,
        "/config/host",
        proxyEnabled=p is not None,
        proxyType="http",
        proxyHostname=p["host"] if p else "",
        proxyPort=p["port"] if p else 8080,
        proxyBypassFilter=",".join(p["direct"]) if p else "",
        proxyBypassLocalAddresses=True,
    )


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


# the qualities a release may be, the best last as in their lists: a bdrip
# 1080p, then a web one, then 720p. a 720p gets replaced by a 1080p once
# there is one (cutoff), a web 1080p stays
QUALITIES = {
    "radarr": ["WEB 720p", "Bluray-720p", "WEB 1080p", "Bluray-1080p"],
    "sonarr": ["HDTV-1080p", "WEB 720p", "Bluray-720p", "WEB 1080p", "Bluray-1080p"],
}
CUTOFF = "WEB 1080p"
PROFILE = "BDRip 1080p"
# among equal qualities a russian dub wins (rutracker's titles get "RUS",
# below). no upgrade for it alone: cutoffFormatScore 0
RUSSIAN = 11
RUSSIAN_SCORE = 10


def profile(api, app):
    formats = api.get("/customformat")
    cf = next((f for f in formats if f["name"] == "Russian"), None)
    spec = next(s for s in api.get("/customformat/schema") if s["implementation"] == "LanguageSpecification")
    spec = dict(spec, name="Russian", negate=False, required=False)
    spec.pop("presets", None)
    for f in spec["fields"]:
        if f["name"] == "value":
            f["value"] = RUSSIAN
    body = {"name": "Russian", "includeCustomFormatWhenRenaming": False, "specifications": [spec]}
    if cf is None:
        api.post("/customformat", body)
        formats = api.get("/customformat")
    else:
        api.put(f"/customformat/{cf['id']}", dict(body, id=cf["id"]))

    p = next((p for p in api.get("/qualityprofile") if p["name"] == PROFILE), None)
    if p is None:
        p = api.get("/qualityprofile/schema")
    allowed = QUALITIES[app]
    cutoff = None
    for item in p["items"]:
        label = item.get("name") or item["quality"]["name"]
        item["allowed"] = label in allowed
        for sub in item.get("items", []):
            sub["allowed"] = item["allowed"]
        if label == CUTOFF:
            cutoff = item.get("id") or item["quality"]["id"]
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
                "score": RUSSIAN_SCORE if f["name"] == "Russian" else scores.get(f["id"], 0),
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
        wanted = {"uindex", "thepiratebay", "1337x"}
        have = lambda: {x["definitionName"] for x in api.get("/indexer/schema")}
        if wanted - have():
            command(api, "IndexerDefinitionUpdate")
        if missing := wanted - have():
            raise RuntimeError(
                f"no definitions of {', '.join(sorted(missing))}: indexers.prowlarr.com doesn't answer"
                " (journalctl -u prowlarr, useProxy in nixos/services/arr/default.nix)"
            )

    steps = {
        "proxy": lambda: proxy(api),
        "definitions": definitions,
        # cloudflare's checks for 1337x and uindex, a tracker with the tag
        # goes through it. prowlarr tests it with prowlarr.servarr.com
        # (journalctl -u flaresolverr when it fails), through the proxy too
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
    # sonarr take the one of the tracker before
    def tracker(name, definition, priority, fields=None, tags=()):
        return lambda: provider(
            api,
            "/indexer",
            name,
            lambda x: x["definitionName"] == definition,
            fields or {},
            enable=True,
            priority=priority,
            appProfileId=1,
            tags=list(tags),
        )

    if sec.get("rutracker_username"):
        # its titles are russian / english [year, country, genre, quality]:
        # russian letters out, the [] after the name, "RUS" for the dub
        steps["rutracker"] = tracker(
            "RuTracker.org",
            "RuTracker.org",
            1,
            {
                "username": sec["rutracker_username"],
                "password": str(sec.get("rutracker_password", "")),
                "russianLetters": True,
                "addRussianToTitle": True,
                "moveFirstTagsToEndOfReleaseTitle": True,
            },
        )
    else:
        log("prowlarr: no rutracker_username in secrets/arr.yaml, rutracker skipped")
    steps["uindex"] = tracker("Uindex", "uindex", 2, tags=[flaresolverr])
    steps["thepiratebay"] = tracker("The Pirate Bay", "thepiratebay", 3)
    steps["1337x"] = tracker("1337x", "1337x", 4, tags=[flaresolverr])
    steps["sync"] = lambda: api.post("/command", {"name": "ApplicationIndexerSync"})
    return run("prowlarr", steps)


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
for setup in (lambda: servarr("radarr"), lambda: servarr("sonarr"), lambda: prowlarr(sec), lambda: bazarr(sec)):
    try:
        failed += setup()
    except Exception as e:
        failed += 1
        log(e)
sys.exit(1 if failed else 0)
