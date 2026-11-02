---
name: obsidian
description: Find, read and edit the user's Obsidian notes (the vault ~/HOME/wizzard/Holocron, the mcp__notes__* search). Use when the user asks what is in their notes, asks to find, write, update or organize a note, or asks about something their notes may cover.
---

# The user's Obsidian vault

The vault is `~/HOME/wizzard/Holocron`: plain markdown files, in Russian and English, a note can be in either language whatever the language of the question. It can be large. Never read it whole, never list it recursively, never grep it without a pattern that narrows it down: open only the notes the task needs.

## Finding a note

- By meaning: `mcp__notes__search_docs` with `library` "notes", a short `query` and `limit` 5 to 10. Search in both languages, once in Russian, once in English. Nothing useful: rephrase once in each language (synonyms, abbreviations like спб for Санкт-Петербург).
- By exact text, a tag, a link or a file name: `rg` and `fd` in the vault, for example `rg -l '\[\[Name' ~/HOME/wizzard/Holocron`, `rg -l '#tag\b' ~/HOME/wizzard/Holocron`, `fd -i name ~/HOME/wizzard/Holocron`.
- The search index refreshes every 30 minutes. A note created or changed since then is found only by `rg` and `fd`.
- Say the notes have nothing only after both ways.

## Reading

Read the note's file with the read tool. A search result's url is `file:///notes/<path>`, its file is `~/HOME/wizzard/Holocron/<path>` (url-decoded). Read the whole note, the relevant part is often under a later heading. Follow its `[[links]]` only when the question needs them.

## Writing

Before the first new note of a session, read `.obsidian/app.json` (`newFileFolderPath`, `attachmentFolderPath`) and two or three notes in the target folder. Copy what they do: frontmatter fields, headings, tags, language.

- Links to other notes: `[[Name]]`, `[[Name|text]]`, `[[Name#Heading]]`. The name without `.md`, a path only when two notes share the name. No markdown links between notes.
- Properties: YAML frontmatter at the very top, only the fields the neighbouring notes use.
- Tags: the vault's existing ones. Check a tag with `rg -l '#tag\b'` before inventing one.
- A new note: one topic, the file name is its title (Obsidian shows the file name), none of `* " \ / < > : | ? # ^ [ ]` in it.
- A change: small edits in place, not a rewrite of the whole note. Keep the user's wording.
- Renaming or moving: Obsidian updates links only when it renames a note itself. Ask the user to do it in Obsidian; if they want it done here, update every `[[Old name` that `rg` finds.
- Never touch `.obsidian/`. Never delete a note: name the ones to delete and let the user do it.
- Obsidian picks up changed files by itself, nothing to reload.
- At the end, list the notes created or changed, by path.

Answer from the note text and name the note's path. Reply in the language of the user's question.
