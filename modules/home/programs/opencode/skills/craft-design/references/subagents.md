# Subagents for design

A subagent is useful for exactly two things: a plan drawn without having built anything, and a review by someone who did not build it. Both are destroyed by handing it your own reasoning.

## Why it works

- Fresh context has no attachment to the first idea and no sunk cost to defend.
- The author reads intent into the render; a reviewer only sees the render.
- A plan from a fresh context surfaces the structural mistake before it is drawn twice.

## What it costs

- A subagent does not see the session: brief, criteria, format and ids go in the prompt verbatim.
- Two model calls plus renders per round; reviewing a large deck can cost more than building it.
- A subagent cannot ask the user. Anything unclear comes back as an assumptions list — read it.

## When to delegate

| Situation | Delegate? |
|---|---|
| Clear brief, one screen, quick build | No. Build and self-check with `review.md`. |
| New domain, real research needed before a layout | Plan subagent, with the research in the brief. |
| Several screens, sections or a long deck | Plan subagent for structure; the main agent builds. |
| Artifact goes to a person (client, boss, publish) | Review subagent. |
| The main model cannot read images | Numeric review only, and say the visual check was skipped. |
| Polish after an agreed plan | No. That is a diff with a target, not a review. |
| You already think it is good | Review subagent. This is when self-review fails most. |

## Roles

| Role | Does | Does not |
|---|---|---|
| Planner | structure, grid, type, colour roles, risks, acceptance checks | open the document, build, edit |
| Reviewer | inspect, render, report findings against criteria | edit, rewrite, invent new goals |
| Main | decide, build, apply P0/P1, reject with a reason, report | hide a rejected finding |

## Prompt contract

Every delegation prompt carries:

1. Role and one sentence of job.
2. Brief verbatim, and the acceptance criteria verbatim.
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
App and format: <app>, <width>x<height>

Return only:
1. Structure: sections in reading order, one line each, and what the viewer
   must notice first.
2. Grid and measure: columns, margins, gutter, max content width.
3. Type: 3-4 roles with size, weight, line-height.
4. Colour: roles with hex, plus the contrast ratio of every text pair.
5. Content: what exists, what is missing, what to cut.
6. Risks: 2-3 ways this fails, and the check that catches each.
7. Acceptance checks: 3-6 lines a reviewer can test.

Assumptions you had to make: one line each, at the end.
```

## Reviewer prompt

```
You are the design reviewer. Artifact: <doc id or path> in <app>.
You may inspect and render it. Do not modify it.

Criteria, the only things that count: <paste>
What was asked: <brief, 3 lines>
Round: <n> of 2.

Open it, render at final size, inspect geometry. For every finding:

id | severity | criterion violated | measured deviation | location

P0 wrong information, unreadable text, clipped content, broken layout.
P1 violates a criterion and is cheap: alignment, spacing, contrast, hierarchy.
P2 taste, or an idea that was never asked for. Backlog, not a fix.

Rules:
- Max 5 findings, sorted by severity.
- Every finding names a criterion and a number.
- Do not repeat a resolved item without new evidence against its criterion.
- No plan, no praise, no rewrite. Nothing outside the schema.

End with: VERDICT: PASS | FIX (n P0, n P1)
```

Add to the criteria list, as needed: "nothing outside the format", "no placeholder text left", "every required text present". Vague criteria produce vague findings, which produce the loop.

## The loop

```
build -> render -> inspect
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
Look at: <what the user should judge themselves>
```

## Vision

- A visual review needs a model that reads images. A text-only model can still review geometry, contrast ratios and content — say that the pixel check was skipped.
- Local `llama-swap/qwen-uncensored-vision` is vision-capable. The subagent tool's model is set only on the user's word, so ask.
- The reviewer must render itself. A screenshot described in prose is not a review.

## Failure modes

| Symptom | Cause | Fix |
|---|---|---|
| Endless P2 findings | criteria are vague, or "improve it" was in the prompt | rewrite criteria as testable lines, cap findings |
| Same finding twice | reviewer has no memory of round 1 | pass the resolved list in, forbid the reopen |
| Reviewer rewrites the design | it was given edit permission or a mockup to "improve" | read-only, schema only |
| Plan ignores the brief | brief was summarised, not pasted | paste it verbatim |
| Reviewer praises everything | it saw your reasoning and agrees with it | strip justification, keep criteria |
