# Subagents for design

Two jobs, two rules: the plan is written by a subagent that did not build anything, and the review is written by one that did not build it either. Both are destroyed by handing over your own reasoning.

## Why the planner is mandatory

The builder plans what it can draw. A fresh context plans what the artifact needs, and it costs one call to find out that the structure is wrong before it is drawn twice. On a real diagram this is six redraws saved.

The only exception is a visual the user called trivial in the request. Not "small", not "obvious": trivial, in their words.

## Model choice

Ask once per task, from the models available right now, never from memory:

1. `opencode-go/gpt-6-luna` — default, cheap, fine for both plan and review.
2. the main session model — no surprise, same taste as the build.
3. one model that is good at design or reads images.

No local models in the first three. Add "if you want a local one, type it" and use exactly what the user writes. Check the list with `tools.opencode.models`; a model that is not in the result is not available.

For the review, the model has to see the render. If the chosen one cannot, say so before calling it: the review is then source-only, and the main agent does the pixel pass itself.

## What it costs

- A subagent does not see the session: brief, criteria, sources and ids go in the prompt verbatim.
- Two model calls plus renders per round; reviewing a long deck can cost more than building it.
- A subagent cannot ask the user. Anything unclear comes back as an assumptions list — read it.

## Roles

| Role | Does | Does not |
|---|---|---|
| Planner | structure, grid, type, colour roles, risks, acceptance checks | open the document, build, edit |
| Reviewer | inspect, render, report findings against criteria | edit, rewrite, invent new goals |
| Main | decide, build, apply P0/P1, reject with a reason, report | hide a rejected finding |

## Prompt contract

Every delegation prompt carries:

1. Role and one sentence of job.
2. Brief verbatim, acceptance criteria verbatim, and the source list.
3. App, format, size, the tool names it may use.
4. Permission line: "you may inspect and render", or "plan only, do not open the document".
5. Exact output schema.
6. Budget: findings count or rounds.

Do not include your reasoning for the choices. That turns the review into grading your story.

## Planner prompt

```
You are the design planner. Plan only: do not open, create or modify the
artifact.

Brief: <paste>
Acceptance criteria: <paste>
Sources: <fact -> note path, one per line>
App and format: <app>, <width>x<height>

Return only:
1. Structure: sections in reading order, one line each, and what the viewer
   must notice first.
2. Grid and measure: columns, margins, gutter, max content width.
3. Type: 3-4 roles with size, weight, line-height.
4. Colour: roles with hex, plus the contrast ratio of every text pair.
5. Content: what exists, what is missing, what to cut.
6. Missing or unverified facts: anything in the sources you could not confirm,
   and what would confirm it.
7. Risks: 2-3 ways this fails, and the check that catches each.
8. Acceptance checks: 3-6 lines a reviewer can test.

Assumptions you had to make: one line each, at the end.
```

## Reviewer prompt

```
You are the design reviewer. Artifact: <doc id or path> in <app>.
You may inspect and render it. Do not modify it.

Criteria, the only things that count: <paste>
What was asked: <brief, 3 lines>
Round: <n> of 2.

Open it, render at the size a reader sees, inspect geometry. For every
finding:

id | severity | criterion violated | measured deviation | location

P0 wrong information, unreadable text, clipped content, broken layout.
P1 violates a criterion and is cheap: alignment, spacing, contrast, collisions.
P2 taste, or an idea that was never asked for. Backlog, not a fix.

Rules:
- Max 5 findings, sorted by severity.
- Every finding names a criterion and a number.
- Do not repeat a resolved item without new evidence against its criterion.
- No plan, no praise, no rewrite. Nothing outside the schema.

End with: VERDICT: PASS | FIX (n P0, n P1)
```

## The loop

```
plan (subagent) -> brief agreed -> build -> render -> inspect
round = 0
while review requested and round < 2:
    round += 1
    findings = reviewer(criteria, round)
    apply P0 and P1 only
    render
deliver + open list
```

Rules that stop it:

1. Budget lives in the prompt ("round n of 2"), not in your mood.
2. Round 2 must produce fewer P0+P1 than round 1. Not fewer: stop and report.
3. A finding reopens only with new evidence tied to a criterion.
4. The main agent may reject a finding with one line of reason; that is final for the round.
5. P2 and new ideas go to a backlog message, never into the build.
6. A third round happens only if the user asks, and you say what it is for.
7. The reviewer never edits. An editor finds something to change because it has to change something.

## Stop report

```
Rounds: 2. Fixed: 7. Open: 2 (P2). Rejected: 1 (accent colour was in the brief).
Facts changed: VPS site NL -> US (kessel.md, ipinfo).
Look at: <what the user should judge themselves>
```

## Vision

- The reviewer renders itself. A screenshot described in prose is not a review.
- The reviewer must see the render; collisions, spacing and clipping are its findings, not the builder's. GPT-6 Luna reads renders fine, a local vision model is optional.
- A text-only reviewer can still check geometry, contrast ratios and content against sources. Say that the pixel check was skipped; do not count it as passed.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Endless P2 findings | criteria are vague, or "improve it" was in the prompt | rewrite criteria as testable lines, cap findings |
| Same finding twice | reviewer has no memory of round 1 | pass the resolved list in, forbid the reopen |
| Reviewer rewrites the design | it was given edit permission or a mockup to "improve" | read-only, schema only |
| Plan ignores the brief | brief was summarised, not pasted | paste it verbatim |
| Reviewer praises everything | it saw your reasoning and agrees with it | strip justification, keep criteria |
| Facts wrong in the artifact | the brief inherited them from the old version | source list in the brief, "unverified" in the plan |
