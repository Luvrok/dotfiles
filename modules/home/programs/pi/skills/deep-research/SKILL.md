---
name: deep-research
description: Multi-source research with a written, cited report. Use when the user asks for deep or thorough research, a comparison of options, a review of a topic, or "find out everything about X". For a quick fact use plain web search.
---

# Deep research

Web access comes from `web_search`, `fetch_content`, `get_search_content` and `source_check` of pi-web-access. The configured route tries SearXNG first, then keyless providers. The budget below replaces the "3 searches" rule of AGENTS.md; everything else in AGENTS.md still holds.

## Two modes

- Fast, the default. Omit `provider` on `web_search`. The route falls through SearXNG, Exa, degoog, DuckDuckGo and Keenable on `transient`, `quota`, `network`, `invalid-response` and `unsupported` (the installed pi-web-access 0.44.0 allows these five). Third-party providers see the query, so this mode is only for non-sensitive topics.
- Private. Pass `provider: "searxng"` on every search when the topic is sensitive. Strict, no fallback: queries stay behind the local instance and its VPN. Slower, and a SearXNG ban stops the research until it clears.

One SearXNG failure in Fast mode costs one fast attempt, then the route continues. After two SearXNG failures in one session, pass `provider: "exa"` for the remaining searches instead of waiting for the local instance each time.

## Steps

1. **Scope.** Restate the question in one or two lines. Split it into 3 to 6 sub-questions that together answer it. Ask once if the question has no time frame, goal or region.
2. **Plan.** List the sub-questions and the first query for each. Wait for approval only when there are more than 6 sub-questions or the user asked to check the plan.
3. **Local sources first.** Use `mcp__docs__*` for libraries and `mcp__notes__*` for the user's own notes before the web.
4. **Search.** One `web_search` call per sub-question, key terms rather than a sentence, `numResults: 5`. Keep the default `workflow: "none"`: no curator, no summary model call. Never batch queries in one call, since concurrent queries hit SearXNG as a burst. Prefer pages that cover many things at once: official docs, changelogs, Wikipedia lists, benchmarks. Budget: 12 searches in total. Identical queries within an hour come from cache and cost no upstream request.
5. **Read.** Open the 1 or 2 best pages per sub-question with one `fetch_content({ urls: [...] })` call. A bot wall or an empty shell is retried by the tool through Jina Reader without a key. To pull a specific fact from a stored page, use `get_search_content({ responseId, findText: "term" })` instead of reading the whole page.
6. **Verify.** For a number, a date or an "X is better than Y" claim, run `source_check({ claim, fetchContent: true })`. Two independent sources for a claim that matters, primary sources over blogs that repeat them. Mark single-source claims. Note the date of each source; old sources are weak on fast-moving topics.
7. **Stop** when every sub-question has an answer or the budget is spent. Say what stayed open, ask before going over the budget.
8. **Report** in the language of the user:
   - the answer first, 3 to 6 lines;
   - findings by sub-question, each claim with its source url;
   - what is uncertain, conflicting or missing;
   - for a choice between options, a short table and one recommendation.
   Keep the report as a note with the `obsidian` skill when asked.

## Failure handling

- Empty or off-topic result: 0.44.0 does not fall through on it. Rephrase once, or pass `provider: "exa"` explicitly, then take the next sub-question.
- `quota` from DuckDuckGo: the provider already pauses itself for 30 minutes. Do not retry it manually.
- `fetch_content` returns a cookie notice or paywall: try the canonical URL, a Wikipedia mirror or the project docs once before giving up.
- A guess is marked as a guess. Nothing is stated that no source said.
- Give the gist and the url, not long passages.
