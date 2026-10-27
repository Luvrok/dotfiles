# kodi turns on an add-on it didn't install itself only by hand. this marks
# them on in its add-on database: enable-addons.py DATADIR ID... no
# database yet (kodi never ran): nothing, the next switch does it. kodi
# reads it when it starts
import glob
import os
import sqlite3
import sys

datadir, ids = sys.argv[1], sys.argv[2:]
dbs = glob.glob(os.path.join(datadir, "userdata/Database/Addons*.db"))
if not dbs:
    sys.exit()
db = max(dbs, key=lambda p: int(os.path.basename(p)[len("Addons") : -len(".db")]))

with sqlite3.connect(db) as c:
    for id in ids:
        c.execute(
            "insert into installed (addonID, enabled, installDate) values (?, 1, datetime('now'))"
            " on conflict (addonID) do update set enabled = 1",
            (id,),
        )
