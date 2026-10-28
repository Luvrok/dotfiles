---
name: docs
description: Search the local documentation index (docs_* tools). Use before answering about or writing code for a library that is indexed there, and instead of web search for it.
---

# Local docs index

The `docs_*` tools search documentation indexed on this machine. It is faster and more exact than web search.

## Steps

1. Call `docs_list_libraries` first. Use only names from its answer.
2. Call `docs_search_docs` with `library`, a short English `query` worded the way the docs would say it (option, function or flag names, not a question), and `limit` 5 to 10.
3. When a passage is cut short, call `docs_read_page` with the same `library` and the result's url as `pathOrUrl`.
4. Nothing useful: rephrase once, or try a related library. For Nix: nixos-manual for options and modules, nix-manual for the CLI and language, nixpkgs-manual for builders, fetchers and overrides, nix-dev for tutorials.
5. Still nothing: say so, then use web search.

## Rules

- Answer from the passages and name the page url.
- Don't make up option names or flags the docs didn't show.
