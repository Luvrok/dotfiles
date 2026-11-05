---
name: deep-research
description: Thorough multi-source research with a written, cited report. Use only when the user asks for deep or thorough research, a comparison of options, a review of a topic, or "find out everything about X". For a quick fact use plain web search.
---

# Deep research

The searches go through a self-hosted SearXNG that search engines ban on bursts. The budget below replaces the "3 searches" rule of AGENTS.md for this skill, nothing else changes: one search at a time, read before the next one.

## Steps

1. **Scope.** Restate the question in one or two lines. Split it into 3 to 6 sub-questions that together answer it. If the question is vague (no time frame, no goal, no region), ask the user once before searching.
2. **Plan.** Show the sub-questions and the first query for each. Wait for the user's go only when the research is big (more than 6 sub-questions or the user asked to check the plan). Otherwise go on.
3. **Local sources first.** The `docs` skill for libraries and the `notes` skill for the user's own notes, before the web.
4. **Search.** One query per sub-question: key terms, not a sentence. Prefer pages that cover many things at once (official docs, changelogs, Wikipedia lists, comparison and benchmark pages). A budget of 10 searches in all. Open and read the 1 or 2 best results of each search (webfetch), do not judge by snippets.
5. **Check.** A claim that matters (a number, a date, "X is better than Y") needs two independent sources, or is marked as one source. Prefer primary sources: the vendor's docs, the paper, the repo, over blogs that repeat them. Note the date of each source, old ones for fast-moving topics are weak.
6. **Stop** when every sub-question has an answer or the budget is spent. Say what stayed open and ask before going over the budget.
7. **Report**, in the user's language:
   - the answer first, 3 to 6 lines;
   - then the findings by sub-question, each claim with its source url;
   - what is uncertain, conflicting or missing;
   - for a choice between options: a short table and one recommendation.
   If the user wants it kept, write it as a note with the `obsidian` skill.

## Rules

- Never state something no source said. A guess is marked as a guess.
- Empty result or error: rephrase once, then take the next sub-question.
- Don't copy long passages, give the gist and the url.
