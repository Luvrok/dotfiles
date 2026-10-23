# dedupe.py <dir> <id>...
# keeps a section (an h2 with one of these ids, up to the next h1/h2) only in
# the first html file that has it. generated pages repeat the same block on
# every page (nix3-* commands: the common options), so search came back with
# the same chunk from every one of them
import pathlib
import re
import sys

root = pathlib.Path(sys.argv[1])
seen = set()
for path in sorted(root.rglob("*.html")):
    html = path.read_text(encoding="utf-8", errors="replace")
    out = html
    for sid in sys.argv[2:]:
        pat = re.compile(
            r'<h2 id="' + re.escape(sid) + r'".*?(?=<h[12][ >]|</main>|\Z)', re.S
        )
        if not pat.search(out):
            continue
        if sid in seen:
            out = pat.sub("", out)
        else:
            seen.add(sid)
    if out != html:
        path.write_text(out, encoding="utf-8")
