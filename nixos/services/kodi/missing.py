# kodi-missing: the videos on the sources that aren't in kodi's library, a
# movie or an episode the scraper didn't find. kodi only says so in its
# debug log. reads the newest MyVideos*.db, run it with kodi closed or
# open, it only reads
import glob
import os
import sqlite3
import sys
import xml.etree.ElementTree as ET

datadir = os.environ.get("KODI_DATA", os.path.expanduser("~/.kodi"))
videos = {".mkv", ".mp4", ".avi", ".m4v", ".mov", ".webm", ".ts", ".wmv", ".mpg", ".mpeg"}

dbs = sorted(
    glob.glob(os.path.join(datadir, "userdata/Database/MyVideos*.db")),
    key=lambda p: int(os.path.basename(p)[len("MyVideos") : -len(".db")]),
)
if not dbs:
    sys.exit("no MyVideos*.db, kodi hasn't scanned anything yet")
db = sqlite3.connect(f"file:{dbs[-1]}?mode=ro", uri=True)
known = {
    path + name
    for path, name in db.execute(
        "select path.strPath, files.strFilename from files"
        " join path using (idPath)"
        " where idFile in (select idFile from movie union select idFile from episode)"
    )
}

sources = ET.parse(os.path.join(datadir, "userdata/sources.xml"))
for source in sources.iterfind("video/source"):
    root = source.findtext("path")
    for dir, _, names in os.walk(root):
        for name in sorted(names):
            file = os.path.join(dir, name)
            ext = os.path.splitext(name)[1].lower()
            # kodi skips samples the same way
            if ext in videos and "sample" not in name.lower() and file not in known:
                print(file)
