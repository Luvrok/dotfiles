# docs-mcp-sync <sources.json> [refresh]
# brings the index in line with sources.nix. state.json remembers what the
# last runs scraped, so libraries added by hand are never touched. refresh
# also refreshes the sources that didn't change
want=$1
mode=${2:-sync}
state=${STATE_DIRECTORY:-/var/lib/docs-mcp-sync}/state.json

# sync and refresh write the same store, one at a time
exec {lock}>"$state.lock"
flock "$lock"

[ -f "$state" ] || echo '{}' >"$state"
failed=0

save() {
  jq --arg n "$1" --argjson e "$2" \
    'if $e == null then del(.[$n]) else .[$n] = $e end' "$state" >"$state.tmp"
  mv "$state.tmp" "$state"
}

existing=$(LOG_LEVEL=ERROR docs-mcp list </dev/null | jq -r '.[].name')

# gone from sources.nix
while IFS= read -r name; do
  if grep -qxF "$name" <<<"$existing"; then
    mapfile -t version < <(jq -r --arg n "$name" '.[$n].version[]' "$state")
    echo "removing $name"
    docs-mcp remove "$name" "${version[@]}" </dev/null || {
      failed=1
      continue
    }
  fi
  save "$name" null
done < <(jq -r --slurpfile w "$want" 'keys[] | select(IN($w[0][].name) | not)' "$state")

while IFS= read -r entry; do
  name=$(jq -r .name <<<"$entry")
  mapfile -t version < <(jq -r '.version[]' <<<"$entry")

  # unchanged and still in the index (it can be removed by hand)
  if [ "$(jq -r --arg n "$name" '.[$n].key // ""' "$state")" = "$(jq -r .key <<<"$entry")" ] &&
    grep -qxF "$name" <<<"$existing"; then
    if [ "$mode" = refresh ]; then
      echo "refreshing $name"
      docs-mcp refresh "$name" "${version[@]}" </dev/null || failed=1
    fi
    continue
  fi

  mapfile -t flags < <(jq -r '.flags[]' <<<"$entry")
  echo "scraping $name"
  if docs-mcp scrape "$name" "$(jq -r .url <<<"$entry")" "${flags[@]}" "${version[@]}" --replace </dev/null; then
    save "$name" "$entry"
  else
    failed=1
  fi
done < <(jq -c '.[]' "$want")

exit "$failed"
