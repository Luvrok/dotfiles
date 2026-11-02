# Global rules

pi's global context (~/.pi/agent/AGENTS.md, modules/home/programs/pi), loaded in every session.

## Web search

Searches go through a self-hosted SearXNG behind a VPN. Search engines rate-limit it: a burst of queries gets it banned for minutes and every search fails. So search like a person, not a crawler:

- Think first. Work out exactly what you need to know and the one query most likely to answer it. Write it the way a search engine wants: key terms, not a question.
- One search at a time, never several in parallel.
- Read the results before searching again. Open the one or two best pages and read them: an overview page (a Wikipedia list, the official docs, a changelog) usually answers the whole question at once.
- Don't search variations of the same thing one by one (each category, each year, each version): find the page that lists them all.
- At most 3 searches for one question. If they didn't answer it, stop, say what you found and what is missing, and ask the user before searching more.
- An empty result or an error is not a reason to retry at once: rephrase once, or stop.
