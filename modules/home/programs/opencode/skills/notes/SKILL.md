---
name: notes
description: Search the user's Obsidian notes (notes_* tools). Use whenever the user asks what is in their notes, asks to find a note, or asks about something their notes may cover.
---

# The user's notes

The `notes_*` tools search the user's Obsidian vault, indexed on this machine as the library `notes`. The notes are in Russian and English, a note can be in either language whatever the language of the question.

## Steps

1. Call `notes_search_docs` with `library` "notes", a short `query` and `limit` 5 to 10. Search in both languages: once in Russian, once in English.
2. When a passage is cut short, call `notes_read_page` with `library` "notes" and the result's url as `pathOrUrl`. Read the whole note: the relevant part is often under a later heading.
3. Nothing useful: rephrase once in each language (synonyms, abbreviations like спб for Санкт-Петербург).

## Rules

- Say the notes have nothing only after step 3.
- Answer from the note text and name the note's path.
