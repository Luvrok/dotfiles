---
name: wiki
description: The agent's own wiki in memory/wiki. Use when the user asks to ingest a source into the wiki, to remember a synthesis or a principle, what the wiki says about a topic, or to check, lint or rebuild the wiki.
---

# Wiki

`memory/wiki/` in the vault is the agent's knowledge base: pages that synthesize several sources, mark contradictions and state principles. The user reads it, the agent writes it. A digest of one source is a normal note, not a wiki page: notes are the user's, the wiki is yours.

## Page format

```markdown
---
title: Nix Flake Updates
type: concept
summary: Обновление и откат flake, почему пин на ревизию, а не на ветку
updated: 2026-11-15
sources: [3-resources/nixos/flake-update.md]
domains: [infra]
---
# Nix Flake Updates

Две строки: что это и главный вывод.

## How it works
...
## Related
- [[nixos-flakes]]
```

- Flat folder, `memory/wiki/<kebab-case>.md`, type in the frontmatter, not in the path.
- `type` is one of `concept`, `entity`, `analysis`, `decision`, `project`, `source`.
- The first line is `#` with the same text as `title`: the indexer takes the page name only from `#`, otherwise it shows `Untitled`.
- `summary` is one sentence, up to 200 characters, written by meaning, not copied from the lead.
- A paragraph of 2-3 sentences right under `#`: the search returns chunks cut at `##`, this paragraph keeps the chunk readable.
- `##` sections are chunk boundaries, so one idea per section.
- `sources` are vault-relative paths. `updated` is the date of the last rewrite, not of the first write.
- `canonical: true` when the wiki is the primary place for the fact and a note only points here.

## Ingest

1. Read the whole source, not the first paragraph.
2. Read `memory/wiki/index.md` and search the `wiki` library for the topic.
3. A page already covers it: extend that page. A new page only for a genuinely different topic. Near duplicates are the default failure.
4. Write the page in the format above. Keep it under ~150 lines.
5. New data contradicts the page: rewrite the claim and say what changed in the same section. Do not keep two versions with equal weight.
6. `python3 memory/tools/memory-index build`, then `lint`. A page that the indexer cannot title is a bug, not a cosmetic issue.
7. Commit the vault in one commit with the source if both changed.
8. Tell the user one line: which page, which sections changed.

## Query

1. `memory/wiki/overview.md`, then `index.md` or a search in the `wiki` library.
2. Answer from the page and name its path. When the user wants the raw material, follow `sources`.
3. Nothing in the wiki: say so, then search the notes. Do not invent a page.

## Lint

`python3 memory/tools/memory-index lint` finds missing or mismatched `#`, broken `sources`, stale pages, broken wikilinks, an index out of date.

Beyond the script, look at the wiki as a whole when asked:

- near-duplicate pages, one concept split in two;
- pages with no inbound links;
- concepts that keep coming up in conversation but have no page;
- claims that a newer source contradicts.

Propose fixes. Deleting a page needs the user's word.

## Rules

- Never edit `memory/wiki/index.md` by hand: it is generated.
- `overview.md` is 15-20 lines. A new domain there when a domain appears or disappears, not per page.
- A principle needs two sources or an explicit decision. One source is a note, not a page.
- A personal conclusion never becomes a wiki principle, even a weighed one: taste and preferences stay in `memory/`, the wiki keeps how things work and why.
- Memory about the user (identity, preferences, state) stays in `memory/MEMORY.md` and `memory/long/`, not in the wiki.
