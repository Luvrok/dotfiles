---
name: notes
description: Search the user's Obsidian notes (notes_* tools). Use whenever the user asks what is in their notes, asks to find a note, or asks about something their notes may cover.
---

# The user's notes

The `notes_*` tools search the user's Obsidian vault, indexed on this machine in three libraries:

| Library | What is inside |
|---|---|
| `wiki` | the agent's own wiki, `memory/wiki/`: synthesis and principles |
| `self` | the agent's memory about the user, `memory/`: core, long notes, journal |
| `notes` | the user's notes: PARA, daily, resources |

The notes are in Russian and English, a note can be in either language whatever the language of the question.

## Steps

1. Search in this order, stop when the answer is there: `wiki`, then `self`, then `notes`. Same `query`, `limit` 5 to 10.
2. Search in both languages: once in Russian, once in English.
3. When a passage is cut short, call `notes_read_page` with the same `library` and the result's url as `pathOrUrl`. Read the whole note: the relevant part is often under a later heading.
4. Nothing useful: rephrase once in each language (synonyms, abbreviations like спб for Санкт-Петербург).

## Rules

- Say the notes have nothing only after step 4.
- Answer from the note text and name the note's path.
- The index is refreshed every 30 minutes: a page written minutes ago is read by path, not search.
