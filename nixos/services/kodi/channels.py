# kodi's tv channels (./userdata.nix, kodi-channels.timer): every list in
# CONFIG put together into one m3u for iptv simple, nothing left out, each
# list its own group. the links that don't open get a "✗ " before their
# name, once a day, so the dead ones show. a fix replaces a channel's link
# by its name (a list's link that's gone, a better one found by hand).
#   channels.py CONFIG.json OUT.m3u
import json
import os
import re
import sys
import urllib.request
from concurrent.futures import ThreadPoolExecutor

C = json.load(open(sys.argv[1]))
OUT = sys.argv[2]
# straight from this machine, as kodi plays them: no proxy from the env
OPENER = urllib.request.build_opener(urllib.request.ProxyHandler({}))
AGENT = "Mozilla/5.0 (X11; Linux x86_64; rv:140.0) Gecko/20100101 Firefox/140.0"
DEAD = "✗ "


def fetch(url, limit=None):
    req = urllib.request.Request(url, headers={"User-Agent": AGENT})
    with OPENER.open(req, timeout=C["timeout"]) as r:
        return r.read(limit)


# a list: [(extinf, url)], the #EXTVLCOPT and the like that come between
# them go with the url
def parse(text, group):
    out, extinf, extra = [], None, []
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("#EXTINF"):
            extinf, extra = line, []
        elif line.startswith("#EXTVLCOPT") or line.startswith("#KODIPROP"):
            extra.append(line)
        elif line and not line.startswith("#") and extinf:
            # its group: the list's name, not the list's own
            extinf = re.sub(r'\s*group-title="[^"]*"', "", extinf)
            extinf = extinf.replace("#EXTINF:-1", f'#EXTINF:-1 group-title="{group}"', 1)
            out.append([extinf, extra, line])
            extinf = None
    return out


def name(extinf):
    return extinf.rsplit(",", 1)[-1].strip()


def alive(url):
    try:
        fetch(url, 2048)
        return True
    except Exception:  # noqa: BLE001 - a dead link is any failure
        return False


channels = []
for group, url in C["lists"].items():
    try:
        channels += parse(fetch(url).decode("utf-8", "replace"), group)
    except Exception as e:  # noqa: BLE001 - one list down, the rest still go
        print(f"{group}: {url}: {e}", flush=True)

fixes = {k.lower(): v for k, v in C["fixes"].items()}
for ch in channels:
    # "Россия-24 (1080p)" is Россия-24's too
    fix = fixes.get(re.sub(r"\s*\(.*\)$", "", name(ch[0])).lower())
    if fix:
        ch[2] = fix

with ThreadPoolExecutor(C["workers"]) as pool:
    ok = list(pool.map(alive, [ch[2] for ch in channels]))

lines = ["#EXTM3U"]
for (extinf, extra, url), up in zip(channels, ok):
    if not up:
        head, _, title = extinf.rpartition(",")
        extinf = f"{head},{DEAD}{title}"
    lines += [extinf, *extra, url]

tmp = OUT + ".part"
os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(tmp, "w") as f:
    f.write("\n".join(lines) + "\n")
os.replace(tmp, OUT)
print(f"{sum(ok)} of {len(ok)} channels open", flush=True)
