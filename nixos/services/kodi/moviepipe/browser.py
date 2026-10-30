# a film's, show's or person's page in the browser (xdg-open): tmdb's,
# imdb's, letterboxd's. majan's film page (more: TMDB, IMDB, LETTERBOXD,
# ../majan-moviepipe.xml), o on a poster (./discover.py, ./person.py)
import os
import subprocess

from arr import error, notify

SITES = {
    "tmdb": lambda kind, tmdb, imdb: tmdb and f"https://www.themoviedb.org/{kind}/{tmdb}",
    "imdb": lambda kind, tmdb, imdb: imdb and (f"https://www.imdb.com/name/{imdb}/" if kind == "person" else f"https://www.imdb.com/title/{imdb}/"),
    # letterboxd has films only, found by their tmdb id
    "letterboxd": lambda kind, tmdb, imdb: tmdb and kind == "movie" and f"https://letterboxd.com/tmdb/{tmdb}/",
}


def url(site, kind, tmdb=None, imdb=None):
    # kind: movie, tv or person (tmdb's words)
    return SITES[site](kind, tmdb, imdb) or None


# ../addons.nix puts xdg-utils' own here: kodi's PATH needn't have it
OPENER = "xdg-open"


def browse(link):
    # kodi's libraries and proxy are its own, not the browser's
    if not link:
        notify("Movie pipe", "No page to open")
        return
    env = {k: v for k, v in os.environ.items() if k not in ("LD_LIBRARY_PATH", "http_proxy", "https_proxy", "no_proxy")}
    try:
        subprocess.Popen([OPENER, link], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError as e:
        error(f"xdg-open: {e.strerror}")
        return
    notify("Opened in the browser", link, 3000)
