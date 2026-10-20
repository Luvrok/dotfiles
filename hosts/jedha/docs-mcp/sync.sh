# docs-mcp-sync <sources.json> [refresh]
# brings the index in line with sources.nix. devdocs and local sources are
# copied to $files as plain html first, the cli reads them from its mount.
# state.json remembers what was scraped, so libraries added by hand are
# never touched. refresh also refreshes github and web sources that didn't
# change, devdocs and local ones change with their key
want=$1
mode=${2:-sync}
state=${STATE_DIRECTORY:-/var/lib/docs-mcp-sync}/state.json
files=${DOCS_MCP_FILES:-/var/lib/docs-mcp-sync/files}
devdocs=${DEVDOCS_URL:-https://devdocs.io}
downloads=${DEVDOCS_DOWNLOADS_URL:-https://downloads.devdocs.io}

# sync and refresh write the same store, one at a time
exec {lock}>"$state.lock"
flock "$lock"

mkdir -p "$files"
[ -f "$state" ] || echo '{}' >"$state"
failed=0
# on the same fs as $files, so a finished copy is one rename
tmp=$(mktemp -d "$files/.tmp.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

save() {
  jq --arg n "$1" --argjson e "$2" \
    'if $e == null then del(.[$n]) else .[$n] = $e end' "$state" >"$state.tmp"
  mv "$state.tmp" "$state"
}

# plain html pages only. docs-mcp loses an index.html inside a folder
tidy() {
  find "$1" -type f ! -name '*.html' -delete
  find "$1" -type f \( -name print.html -o -name 404.html -o -name toc.html \) -delete
  find "$1" -type f -name index.html -execdir mv index.html _index.html \;
  find "$1" -mindepth 1 -type d -empty -delete
}

# fills $files/<name> for devdocs and local sources. called under ||, where
# errexit is off, so every step checks itself
prepare() {
  local name=$1 entry=$2 dir="$tmp/$1" path
  mkdir -p "$dir" || return 1
  case $(jq -r .kind <<<"$entry") in
    devdocs)
      curl -fsSL --retry 3 "$downloads/$(jq -r .slug <<<"$entry").tar.gz" |
        tar -xz -C "$dir" || return 1
      ;;
    local)
      path=$(jq -r .path <<<"$entry")
      if [ -d "$path" ]; then
        cp -rL --no-preserve=mode "$path/." "$dir/" || return 1
      else
        cp -L --no-preserve=mode "$path" "$dir/$name.html" || return 1
      fi
      ;;
  esac
  tidy "$dir" || return 1
  [ -n "$(find "$dir" -name '*.html' -print -quit)" ] || return 1
  rm -rf "${files:?}/$name"
  mv "$dir" "$files/$name"
}

existing=$(LOG_LEVEL=ERROR docs-mcp list </dev/null | jq -r '.[].name')

# devdocs entries carry their mtime in the key, so an update rescrapes them
manifest='[]'
if jq -e 'any(.[]; .kind == "devdocs")' "$want" >/dev/null; then
  if ! manifest=$(curl -fsSL --retry 3 "$devdocs/docs.json"); then
    echo "devdocs manifest download failed"
    manifest='[]'
    failed=1
  fi
fi

# gone from sources.nix
while IFS= read -r name; do
  if grep -qxF "$name" <<<"$existing"; then
    echo "removing $name"
    docs-mcp remove "$name" </dev/null || {
      failed=1
      continue
    }
  fi
  rm -rf "${files:?}/$name"
  save "$name" null
done < <(jq -r --slurpfile w "$want" 'keys[] | select(IN($w[0][].name) | not)' "$state")

while IFS= read -r entry; do
  name=$(jq -r .name <<<"$entry")
  kind=$(jq -r .kind <<<"$entry")
  key=$(jq -r .key <<<"$entry")

  if [ "$kind" = devdocs ]; then
    mtime=$(jq -r --arg s "$(jq -r .slug <<<"$entry")" 'map(select(.slug == $s))[0].mtime // empty' <<<"$manifest")
    if [ -z "$mtime" ]; then
      echo "$name: no devdocs doc $(jq -r .slug <<<"$entry")"
      failed=1
      continue
    fi
    key="$key-$mtime"
    entry=$(jq -c --arg k "$key" '.key = $k' <<<"$entry")
  fi

  # unchanged and still in the index (it can be removed by hand)
  if [ "$(jq -r --arg n "$name" '.[$n].key // ""' "$state")" = "$key" ] &&
    grep -qxF "$name" <<<"$existing"; then
    if [ "$mode" = refresh ] && { [ "$kind" = github ] || [ "$kind" = web ]; }; then
      echo "refreshing $name"
      docs-mcp refresh "$name" </dev/null || failed=1
    fi
    continue
  fi

  echo "scraping $name"
  if [ "$kind" = devdocs ] || [ "$kind" = local ]; then
    prepare "$name" "$entry" || {
      echo "$name: copy failed"
      failed=1
      continue
    }
  fi
  mapfile -t args < <(jq -r '.args[]' <<<"$entry")
  if docs-mcp scrape "$name" "${args[@]}" --replace </dev/null; then
    save "$name" "$entry"
  else
    failed=1
  fi
done < <(jq -c '.[]' "$want")

exit "$failed"
