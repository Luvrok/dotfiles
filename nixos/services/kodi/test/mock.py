# tmdb (8765), radarr (7878), sonarr (8989) and qbittorrent (8140) for the
# kodi of ./run.sh: its tmdb helper asks here (./default.nix), movie pipe
# the arr ports of ../../arr/shared.nix. made up films, shows and people,
# posters drawn with their number (imagemagick), a film and a season
# downloading. what's asked goes to $STATE/mock.log
import json
import os
import re
import subprocess
import threading
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

STATE = os.environ.get("STATE", "/tmp/kodi-test")
IMG = os.path.join(STATE, "img")
os.makedirs(IMG, exist_ok=True)
LOG = open(os.path.join(STATE, "mock.log"), "a")

TITLES = [
    "Sinners", "Harry Potter and the Chamber of Secrets", "Rocky", "A Beautiful Mind", "Steps",
    "All of a Sudden", "The Angry Birds Movie", "De Gaulle: Résistance", "Dune: Part Two", "Blade Runner 2049",
    "1917", "Oppenheimer", "Arrival", "Heat", "The Matrix", "Up", "Her", "Parasite", "Whiplash", "Inception",
    "Interstellar", "Alien", "Se7en", "Memento", "Prisoners", "Sicario", "Drive", "Gravity", "Zodiac", "Fargo",
    "No Country for Old Men", "There Will Be Blood", "The Social Network", "Mad Max: Fury Road", "Gone Girl",
    "The Prestige", "Joker", "Logan", "Moon", "Nope",
]
SHOWS = ["The Rookie", "Severance", "Dark", "Chernobyl", "True Detective", "The Wire", "Fargo", "Mindhunter",
         "Better Call Saul", "Breaking Bad", "Andor", "Slow Horses", "The Bear", "Shogun", "Succession",
         "Fleabag", "Atlanta", "Barry", "Halt and Catch Fire", "Mr. Robot", "Westworld", "The Leftovers"]
PEOPLE = ["Cillian Murphy", "Emily Blunt", "Denis Villeneuve", "Christopher Nolan", "Florence Pugh",
          "Michael B. Jordan", "Ryan Gosling", "Zendaya", "Pedro Pascal", "Rebecca Ferguson", "Jodie Comer",
          "Oscar Isaac", "Ana de Armas", "Austin Butler", "Sydney Sweeney", "Paul Mescal", "Saoirse Ronan",
          "Timothée Chalamet", "Margot Robbie", "Adam Driver"]
SHORT = "A quiet man returns home."
LONG = ("From the heights of notoriety to the depths of depravity, a brilliant but socially awkward "
        "mathematician makes a groundbreaking discovery early in his career and stands on the brink of "
        "international acclaim. But as he accepts secret work in cryptography, he becomes entangled in a "
        "mysterious conspiracy, and his family must watch as he battles the shadows of his own mind. ") * 2
BIO = ("Born in a small town, they started acting in school plays and moved to the city at eighteen. "
       "Their first film role came after years on stage, and a string of acclaimed performances followed. ") * 4


def movie(i):
    n = i - 1000
    return {
        "id": i, "media_type": "movie", "title": TITLES[n % len(TITLES)], "original_title": TITLES[n % len(TITLES)],
        "overview": LONG if n % 3 == 0 else SHORT if n % 3 == 1 else LONG[:240],
        "release_date": f"{1976 + n % 50}-0{1 + n % 9}-1{n % 9}", "poster_path": f"/p{i}.png",
        "backdrop_path": f"/b{i}.png" if n % 5 else None, "vote_average": 6 + (n % 30) / 10, "vote_count": 1000 - n,
        "popularity": 500 - n, "genre_ids": [18, 12], "original_language": "en", "adult": False,
    }


def show(i):
    n = i - 2000
    return {
        "id": i, "media_type": "tv", "name": SHOWS[n % len(SHOWS)], "original_name": SHOWS[n % len(SHOWS)],
        "overview": LONG[:300], "first_air_date": f"{2005 + n % 20}-03-01", "poster_path": f"/p{i}.png",
        "backdrop_path": f"/b{i}.png", "vote_average": 7.5, "vote_count": 500 - n, "popularity": 300 - n,
        "genre_ids": [18], "original_language": "en", "origin_country": ["US"],
    }


def person(i):
    n = i - 3000
    return {
        "id": i, "media_type": "person", "name": PEOPLE[n % len(PEOPLE)], "profile_path": f"/p{i}.png",
        "known_for_department": "Directing" if n % 4 == 2 else "Acting", "popularity": 100 - n, "gender": 1 + n % 2,
        "known_for": [movie(1000 + n), movie(1001 + n)], "adult": False,
    }


def page(items, q, per=20):
    p = int(q.get("page", ["1"])[0])
    total = len(items)
    return {"page": p, "results": items[(p - 1) * per: p * per], "total_pages": (total + per - 1) // per, "total_results": total}


def credits(i):
    cast = [dict(person(3000 + k), character=f"Role {k}", order=k, cast_id=k, credit_id=f"c{i}{k}") for k in range(12)]
    crew = [dict(person(3002), job="Director", department="Directing", credit_id=f"d{i}"),
            dict(person(3003), job="Writer", department="Writing", credit_id=f"w{i}")]
    return {"cast": cast, "crew": crew}


def movie_details(i):
    m = movie(i)
    m.update(runtime=100 + i % 60, genres=[{"id": 18, "name": "Drama"}, {"id": 12, "name": "Adventure"}],
             status="Released", tagline="", imdb_id=f"tt{i:07d}", budget=0, revenue=0,
             production_companies=[], production_countries=[], spoken_languages=[], belongs_to_collection=None,
             credits=credits(i), videos={"results": []}, images={"posters": [], "backdrops": [], "logos": []},
             release_dates={"results": []}, external_ids={"imdb_id": f"tt{i:07d}"}, keywords={"keywords": []},
             reviews={"results": []}, similar=page([movie(1000 + k) for k in range(40)], {}),
             recommendations=page([movie(1000 + k) for k in range(40)], {}))
    return m


def show_details(i):
    s = show(i)
    s.update(number_of_seasons=3, number_of_episodes=30, genres=[{"id": 18, "name": "Drama"}], status="Returning Series",
             seasons=[{"season_number": k, "name": f"Season {k}", "episode_count": 10, "id": i * 10 + k,
                       "air_date": "2020-01-01", "poster_path": f"/p{i}.png", "overview": ""} for k in range(1, 4)],
             created_by=[dict(person(3002), credit_id="cr")], episode_run_time=[50], networks=[], production_companies=[],
             credits=credits(i), aggregate_credits=credits(i), videos={"results": []},
             images={"posters": [], "backdrops": [], "logos": []}, external_ids={"tvdb_id": i}, keywords={"results": []},
             content_ratings={"results": []}, last_episode_to_air=None, next_episode_to_air=None,
             recommendations=page([show(2000 + k) for k in range(30)], {}))
    return s


def person_details(i):
    p = person(i)
    films = [dict(movie(1000 + k), character=f"Role {k}", credit_id=f"pc{k}") for k in range(30)]
    shows = [dict(show(2000 + k), character=f"Role {k}", credit_id=f"pt{k}", episode_count=5) for k in range(8)]
    directed = [dict(movie(1010 + k), job="Director", department="Directing", credit_id=f"pd{k}") for k in range(6)]
    p.update(biography=BIO, birthday="1976-05-25", deathday=None, place_of_birth="Cork, Ireland",
             also_known_as=[], imdb_id="nm0", homepage=None,
             movie_credits={"cast": films, "crew": directed}, tv_credits={"cast": shows, "crew": []},
             combined_credits={"cast": films + shows, "crew": directed}, images={"profiles": []},
             external_ids={}, tagged_images={"results": []})
    return p


ALL_MOVIES = [movie(1000 + k) for k in range(len(TITLES) * 2)]
ALL_SHOWS = [show(2000 + k) for k in range(len(SHOWS))]
ALL_PEOPLE = [person(3000 + k) for k in range(len(PEOPLE) * 2)]


def tmdb(path, q):
    p = path[len("/3"):]
    if m := re.fullmatch(r"/trending/(movie|tv|person|all)/(day|week)", p):
        return page({"movie": ALL_MOVIES, "tv": ALL_SHOWS, "person": ALL_PEOPLE}.get(m[1], ALL_MOVIES), q)
    if m := re.fullmatch(r"/movie/(popular|now_playing|upcoming|top_rated)", p):
        shift = ["popular", "now_playing", "upcoming", "top_rated"].index(m[1]) * 7
        return page(ALL_MOVIES[shift:] + ALL_MOVIES[:shift], q)
    if m := re.fullmatch(r"/tv/(popular|on_the_air|airing_today|top_rated)", p):
        return page(ALL_SHOWS, q)
    if p == "/person/popular":
        return page(ALL_PEOPLE, q)
    if m := re.fullmatch(r"/(movie|tv)/(\d+)/(recommendations|similar)", p):
        return page(ALL_MOVIES[5:] if m[1] == "movie" else ALL_SHOWS[3:], q)
    if m := re.fullmatch(r"/movie/(\d+)", p):
        return movie_details(int(m[1]))
    if m := re.fullmatch(r"/tv/(\d+)", p):
        return show_details(int(m[1]))
    if m := re.fullmatch(r"/person/(\d+)", p):
        return person_details(int(m[1]))
    if m := re.fullmatch(r"/movie/(\d+)/credits", p):
        return credits(int(m[1]))
    if m := re.fullmatch(r"/search/(movie|tv|person|multi)", p):
        text = q.get("query", [""])[0].casefold()
        pool = {"movie": ALL_MOVIES, "tv": ALL_SHOWS, "person": ALL_PEOPLE, "multi": ALL_MOVIES}[m[1]]
        return page([x for x in pool if text in (x.get("title") or x.get("name")).casefold()], q)
    if p.startswith("/genre/"):
        return {"genres": [{"id": 18, "name": "Drama"}, {"id": 12, "name": "Adventure"}]}
    if p == "/configuration":
        return {"images": {"base_url": "http://127.0.0.1:8765/img/", "secure_base_url": "http://127.0.0.1:8765/img/"}}
    return None


def image(name):
    path = os.path.join(IMG, re.sub(r"[^a-z0-9.]", "_", name))
    if not os.path.exists(path):
        n = int(re.sub(r"\D", "", name) or 0)
        wide = name.startswith("b")
        size = "1280x720" if wide else "500x750"
        color = f"hsl({n * 37 % 360},60%,{30 + n % 30}%)"
        subprocess.run(["convert", "-size", size, f"xc:{color}", "-gravity", "center", "-pointsize", "64",
                        "-fill", "white", "-annotate", "0", str(n), path], check=False)
    with open(path, "rb") as f:
        return f.read()


# radarr, sonarr, qbittorrent: one film and a season downloading
QUEUE = {
    "radarr": {"records": [{"id": 1, "downloadId": "AAAA", "title": "Dune.Part.Two.2024.1080p.BluRay.x264", "size": 10e9,
                            "sizeleft": 6e9, "timeleft": "00:20:00", "status": "downloading",
                            "trackedDownloadState": "downloading", "quality": {"quality": {"name": "Bluray-1080p"}},
                            "indexer": "RuTracker (Prowlarr)", "statusMessages": [],
                            "movie": {"title": "Dune: Part Two", "year": 2024, "tmdbId": 1008, "overview": LONG[:200],
                                      "images": [{"coverType": "poster", "remoteUrl": "http://127.0.0.1:8765/img/w500/p1008.png"},
                                                 {"coverType": "fanart", "remoteUrl": "http://127.0.0.1:8765/img/w1280/b1008.png"}]}}]},
    "sonarr": {"records": [{"id": 2, "downloadId": "BBBB", "title": "Severance.S02.1080p.WEB-DL", "size": 20e9,
                            "sizeleft": 15e9, "timeleft": "01:20:00", "status": "downloading",
                            "trackedDownloadState": "downloading", "quality": {"quality": {"name": "WEBDL-1080p"}},
                            "indexer": "1337x", "statusMessages": [],
                            "episode": {"seasonNumber": 2, "episodeNumber": 1},
                            "series": {"title": "Severance", "year": 2022, "tmdbId": 2001, "overview": LONG[:200],
                                       "images": [{"coverType": "poster", "remoteUrl": "http://127.0.0.1:8765/img/w500/p2001.png"}]}}]},
}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def send(self, body, kind="application/json", code=200):
        self.send_response(code)
        self.send_header("Content-Type", kind)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urllib.parse.urlparse(self.path)
        q = urllib.parse.parse_qs(url.query)
        port = self.server.server_address[1]
        LOG.write(f"{port} {self.path}\n")
        LOG.flush()
        if port == 8765 and url.path.startswith("/img/"):
            return self.send(image(url.path.rsplit("/", 1)[1]), "image/png")
        if port == 8765:
            found = tmdb(url.path, q)
            if found is None:
                return self.send(b'{"status_code":34,"status_message":"not found"}', code=404)
            return self.send(json.dumps(found).encode())
        app = {7878: "radarr", 8989: "sonarr"}.get(port)
        if app and url.path == "/api/v3/queue":
            return self.send(json.dumps(QUEUE[app]).encode())
        if port == 8140 and url.path == "/api/v2/torrents/info":
            return self.send(json.dumps([
                {"hash": "aaaa", "size": 10e9, "progress": 0.4, "eta": 1200, "state": "downloading", "dlspeed": 3e6, "num_seeds": 12, "num_complete": 40},
                {"hash": "bbbb", "size": 20e9, "progress": 0.25, "eta": 4800, "state": "stalledDL", "dlspeed": 0, "num_seeds": 0, "num_complete": 9},
            ]).encode())
        return self.send(b"[]")


for port in (8765, 7878, 8989, 8140):
    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
print("mock up", flush=True)
threading.Event().wait()
