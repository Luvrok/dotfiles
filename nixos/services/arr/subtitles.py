# english subtitles become russian on jedha's subtitle translator
# (hosts/jedha/subtitle-translator), next to the video as VIDEO.ru.srt,
# when it has nothing russian: no russian ones from bazarr, no russian
# track inside, no dub.
#   subtitles.py CONFIG add VIDEO SUBTITLES LANGUAGE
#     bazarr's post-processing, after each subtitle it downloads: an
#     english one goes in the queue. in two minutes, the rest of that
#     search (a russian one maybe) is done
#   subtitles.py CONFIG run
#     arr-subtitles.service, while the queue has something: one file at a
#     time, a failed one again in 30 min, 1 h, 2 h... 6 tries
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

import yaml

C = json.load(open(sys.argv[1]))
QUEUE = C["queue"]
WAIT = 120
TRIES = 6
urllib.request.install_opener(urllib.request.build_opener(urllib.request.ProxyHandler({})))

# what follows the video's name: .ru.srt, .rus.hi.srt, .2.Russian.ass... a
# forced one is only the foreign lines, it doesn't count
RUSSIAN = re.compile(r"^\.([^.]+\.)*?(ru|rus|russian)(\.(?!forced)[^.]+)*\.(srt|ass|ssa|vtt|sub)$", re.I)
ENGLISH = re.compile(r"^\.([^.]+\.)*?(en|eng|english)(\.(?!forced)[^.]+)*\.srt$", re.I)


def log(*args):
    print(*args, flush=True)


def add(video, subtitles, language):
    if language != "en" or ".forced." in subtitles:
        return
    # one entry per video, the newest: a new english one waits again
    name = hashlib.sha1(video.encode()).hexdigest()
    for old in glob.glob(f"{QUEUE}/*-{name}.json"):
        os.remove(old)
    put({"video": video, "subtitles": subtitles, "tries": 0}, name, WAIT)


def put(item, name, wait):
    path = f"{QUEUE}/{int(time.time()) + wait}-{name}.json"
    with open(path + ".part", "w") as f:
        json.dump(item, f)
    os.replace(path + ".part", path)


def neighbours(video):
    # the files next to the video named like it: {path: what follows the name}
    base = os.path.splitext(os.path.basename(video))[0]
    folder = os.path.dirname(video)
    return {os.path.join(folder, f): f[len(base) :] for f in os.listdir(folder) if f.startswith(base + ".")}


def russian_inside(video):
    # a russian dub or subtitle track in the video
    out = subprocess.run(
        [C["ffprobe"], "-v", "error", "-show_entries", "stream=codec_type:stream_tags=language", "-of", "json", video],
        capture_output=True,
        text=True,
    )
    streams = json.loads(out.stdout or "{}").get("streams", [])
    return any(
        s.get("codec_type") in ("audio", "subtitle") and s.get("tags", {}).get("language", "").lower() in ("ru", "rus")
        for s in streams
    )


def translate(text, key):
    # the first translator that answers: jedha through jedha-tunnel.nix,
    # then the same one from outside. its answer is a line per event:
    # {"queue":n} {"progress":x,"total":y}, then the text or an error
    body = json.dumps({"q": text, "source": "en", "target": "ru", "api_key": key}).encode()
    for url in C["translators"]:
        req = urllib.request.Request(
            url + "/api/translate", body, {"Content-Type": "application/json"}, method="POST"
        )
        try:
            # blank lines every 15 s while it works
            with urllib.request.urlopen(req, timeout=120) as r:
                for line in r:
                    if not line.strip():
                        continue
                    event = json.loads(line)
                    if "translatedText" in event:
                        return event["translatedText"]
                    if "error" in event:
                        raise RuntimeError(f"{url}: {event['error']}")
            raise RuntimeError(f"{url}: no answer")
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"{url}: {e.code} {e.read().decode(errors='replace')[:300]}") from None
        except (urllib.error.URLError, ConnectionError, TimeoutError) as e:
            log(f"{url}: {e}")
    raise RuntimeError("no translator answers")


def secret(name):
    try:
        with open(C["secrets"]) as f:
            return (yaml.safe_load(f) or {}).get(name)
    except (TypeError, FileNotFoundError):
        return None


def process(item):
    # an error: again later
    video = item["video"]
    if not os.path.exists(video):
        log(f"{video}: gone")
        return
    near = neighbours(video)
    if any(RUSSIAN.match(s) for s in near.values()) or russian_inside(video):
        log(f"{video}: has russian")
        return
    english = item["subtitles"] if os.path.exists(item["subtitles"]) else None
    english = english or next((f for f, s in sorted(near.items()) if ENGLISH.match(s)), None)
    if not english or not english.lower().endswith(".srt"):
        log(f"{video}: no english .srt")
        return
    key = secret("libretranslate_key")
    if not key:
        log("no libretranslate_key in secrets/arr.yaml")
        return
    with open(english, encoding="utf-8-sig", errors="replace") as f:
        text = f.read()
    log(f"{english}: translating")
    russian = translate(text, str(key))
    out = os.path.splitext(video)[0] + ".ru.srt"
    with open(out + ".part", "w", encoding="utf-8") as f:
        f.write(russian)
    if os.path.exists(out):
        os.remove(out + ".part")
    else:
        os.replace(out + ".part", out)
        log(f"{out}: done")


def run():
    while True:
        items = sorted(glob.glob(f"{QUEUE}/*.json"), key=lambda p: int(os.path.basename(p).split("-")[0]))
        if not items:
            return
        path = items[0]
        due, name = os.path.basename(path)[: -len(".json")].split("-", 1)
        if int(due) > time.time():
            time.sleep(min(int(due) - time.time(), 30))
            continue
        item = None
        try:
            with open(path) as f:
                item = json.load(f)
            process(item)
        except Exception as e:
            log(f"{path}: {e}")
            if isinstance(item, dict) and item.get("tries", 0) + 1 < TRIES:
                item["tries"] = item.get("tries", 0) + 1
                put(item, name, 1800 * 2 ** (item["tries"] - 1))
        # a newer english one for it may have taken its place meanwhile
        if os.path.exists(path):
            os.remove(path)


if sys.argv[2] == "add":
    add(*sys.argv[3:6])
else:
    run()
