# the menu (c) of a film, show, season or episode with a tmdb id
# (addon.xml): ./actions.py with what the item is
import sys

from actions import movie, show
from arr import Error, error


def main():
    pick = sys.argv[1] == "pick"
    tag = sys.listitem.getVideoInfoTag()
    kind = tag.getMediaType()
    try:
        if kind == "movie":
            movie(int(tag.getUniqueID("tmdb")), pick)
        elif kind == "tvshow":
            show(int(tag.getUniqueID("tmdb")), kind, None, None, pick)
        else:
            show(int(tag.getUniqueID("tvshow.tmdb")), kind, tag.getSeason(), tag.getEpisode(), pick)
    except Error as e:
        error(e)


main()
