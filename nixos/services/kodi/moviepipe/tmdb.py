# tmdb helper's lists in movie pipe's windows (./person.py, ./discover.py):
# a list's path, what kodi shows of a container, waiting for one to load
import urllib.parse

import xbmc

HELPER = "plugin://plugin.video.themoviedb.helper/"


def helper(**params):
    # tmdb helper's path, the empty params left out
    return f"{HELPER}?{urllib.parse.urlencode({k: v for k, v in params.items() if v})}"


def info(label):
    return xbmc.getInfoLabel(label)


def count(cid):
    return int(info(f"Container({cid}).NumItems") or 0)


def wait(done, seconds, stop=lambda: False):
    # done() within seconds, False when stop() or kodi quits first
    monitor = xbmc.Monitor()
    for _ in range(int(seconds * 10)):
        if stop() or monitor.abortRequested():
            return False
        if done():
            return True
        monitor.waitForAbort(0.1)
    return False


def settle(cid, stop=lambda: False, seconds=30):
    # a container given a new path: kodi keeps its old items till the new
    # ones come, so its count says nothing till it has updated. its count
    # after. a path tmdb helper has cached may be in before a look sees it
    # updating: a second's look for that
    updating = f"Container({cid}).IsUpdating"
    wait(lambda: xbmc.getCondVisibility(updating), 1, stop)
    wait(lambda: not xbmc.getCondVisibility(updating), seconds, stop)
    return count(cid)
