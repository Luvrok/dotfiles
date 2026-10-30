# "trailer" on majan's film page (../majan.nix): its own, or tmdb's first
# trailer (youtube) by tmdb helper's videos of it. tmdb helper's lists
# leave ListItem.Trailer empty
# opened in an external mpv process so kodi keeps running and doesn't wait
import json
import os
import shutil
import subprocess
import urllib.parse

import xbmc

from arr import notify

HELPER = "plugin://plugin.video.themoviedb.helper/"


def find_mpv():
    for candidate in (
        shutil.which("mpv"),
        "/run/current-system/sw/bin/mpv",
        "/etc/profiles/per-user/barnard/bin/mpv",
    ):
        if candidate and os.path.exists(candidate):
            return candidate
    return "mpv"


def videos(kind, tmdb):
    # tmdb helper's videos of a film or show, its trailers first
    found = json.loads(
        xbmc.executeJSONRPC(
            json.dumps(
                {
                    "jsonrpc": "2.0",
                    "id": 1,
                    "method": "Files.GetDirectory",
                    "params": {"directory": f"{HELPER}?info=videos&tmdb_type={kind}&tmdb_id={tmdb}", "media": "video"},
                }
            )
        )
    )
    return [f["file"] for f in found.get("result", {}).get("files") or [] if f.get("filetype") == "file"]


def for_mpv(path):
    # tmdb helper hands youtube as plugin://plugin.video.youtube/...;
    # mpv doesn't know kodi protocols, turn it into a plain youtube url
    if path.startswith("plugin://plugin.video.youtube/"):
        qs = urllib.parse.urlparse(path).query
        params = urllib.parse.parse_qs(qs)
        vid = params.get("video_id", [""])[0]
        if vid:
            return f"https://www.youtube.com/watch?v={vid}"
    return path


def trailer(kind, tmdb):
    title = xbmc.getInfoLabel("ListItem.Title")
    path = xbmc.getInfoLabel("ListItem.Trailer")
    if not path and tmdb:
        path = next(iter(videos(kind, tmdb)), "")
    if not path:
        notify(title, "No trailer on TMDb")
        return
    # закрываем только текущий диалог видео-инфо, не все (иначе при
    # person->film->trailer вспыхивает person page)
    xbmc.executebuiltin("Dialog.Close(VideoInfo,true)", True)
    path = for_mpv(path)
    subprocess.Popen(
        [find_mpv(), path],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )
