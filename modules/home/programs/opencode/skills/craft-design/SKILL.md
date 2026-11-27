---
name: craft-design
description: Take a visual from a topic to a checked artifact, in the StoryTold Craft apps or in Graphviz. FigCraft for interfaces and mockups, VectorCraft for illustrations, logos and one-off SVG, DeckCraft for slides, PhotoCraft for images, WordCraft for documents, Graphviz for diagrams, graphs, network and flow schemas. Covers the brief and the sources, a plan written by a subagent, an explicit choice of app and model, and verification of spacing, alignment, collisions and rendering. Use for a mockup, landing page, dashboard, component, slide deck, poster, logo, diagram, flow chart, schema, network map, infographic, svg, "sdelaj dizajn", "primaj maket", "nabrosaj ekran", "sdelaj shemu", "oformi prezentaciyu", or any visual built with craft tools or dot.
---

# Craft design

Design is decided before pixels: what the thing must do, for whom, in what format, and what makes it right. The plan comes from a subagent, the build from the main agent, and the evidence is a render plus numbers. A canvas without a brief is decoration.

## Hard rules

1. Brief before canvas: goal, audience, medium and size, content, constraints, the check that proves it good. No brief: write five lines and show them.
2. Plan by a subagent, always. The main agent writes the brief and the sources; the subagent decides structure, grid, type and colour; the main agent builds that plan. A visual the user did not call trivial is never planned by the one building it.
3. The app is the user's call. Offer two options with the trade-off in one line each, and build after the answer. Never override the table below silently.
4. Every fact has a source note. The previous version of the artifact is not a source: check the note that owns the fact, or mark it unknown. An inherited error is still your error once you ship it.
5. Structure before style. Blocks, hierarchy and grid first; colour and type last, from a fixed token set.
6. Every number comes from a scale: spacing 4 or 8, type steps of 1.25 or 1.33, 2-3 colours plus neutrals. A one-off value is a bug unless named as one.
7. No invented content. Missing copy gets an obvious placeholder and a line in the missing list.
8. Evidence is a render at the size the reader sees plus numbers from inspect. Check boxes and paths against each other, not boxes alone.
9. Nothing touches text. Think of every label as a box around the glyphs: no edge, arrowhead or shape may enter that box, and none may come closer than 8pt to it. A line that passes between letters leaves every letter whole and still destroys the label. "Almost" is a fail: the box is the rule, not the ink. For a `.dot` file run `scripts/text-collisions.py`; a box entered is P0, not a nitpick.
10. Two renders that do not converge: change the tool or the layout engine, not the numbers.
11. Report measurements, not adjectives, and list what changed against the previous version, facts included.

## Process

1. **Brief and sources** — one paragraph, the must-have content, 3-6 testable acceptance checks, and a fact list with the note each fact comes from.
2. **Plan subagent** — mandatory, before any shape. It returns structure, grid, type and colour. Prompt in `references/subagents.md`.
3. **App choice** — two options, one line each, and the user's answer before the first shape.
4. **Build** — in parts, inspect after each block instead of all at the end.
5. **Check** — `references/review.md`, numbers first, then the render at reader size. For a `.dot` file, `scripts/text-collisions.py` must report zero findings.
6. **Review subagent** — bounded, and its model must see the render. If it cannot, the main agent does the visual pass and says so.
7. **Delta report** — what changed against the previous version, including facts that moved.

## Choose the app

| Artifact | Default | Pick otherwise when |
|---|---|---|
| Diagram, graph, network, schema, flow | Graphviz `.dot` → svg + png | it is a one-off picture with pixel control or art → VectorCraft |
| Screen, dashboard, landing, component, mockup | FigCraft | — |
| Slides, pitch, report deck | DeckCraft | — |
| Photo retouch, composite | PhotoCraft | — |
| Text document, PDF | WordCraft | — |
| Animation on a still | EffectCraft | see the `effectcraft-motion` skill |

Graphviz wins for anything that changes with the data: the source diffs, a host rename is one line, and the render is reproducible. The skill's own name is not an argument for a craft app.

## Which model

Before calling a subagent, ask once per task, from the models available right now:

1. `opencode-go/gpt-6-luna` — default, cheap.
2. the main session model.
3. a model that is good at design or reads images.

No local models in the first three; say "type a local one" and take what the user writes. Check availability with `tools.opencode.models`, never from memory.

## Subagents

The main agent builds and decides. A subagent plans before or reviews after, never both, and never edits the artifact.

- 2 review rounds, 5 findings per round, only P0/P1 fixed. P2 to a backlog, then deliver.
- The reviewer checks written acceptance criteria, never "make it better".
- Details, prompts and anti-loop rules: `references/subagents.md`.

## What makes it look amateur

- Gaps between siblings that differ by 1-2px; alignment that is almost a column edge.
- Type sizes from nowhere: 17, 19, 23px beside a 16px body.
- Contrast under 4.5:1 for body, under 3:1 for large text and icons.
- Diagram labels over lines, arrows into empty space, mixed node sizes, cluster titles crossed by an edge.
- An arrowhead that stops 2pt from a caption. It reads as touching, so it is touching.
- A line through a text box: the letters stay whole, the label is still unreadable.
- Equal padding that looks unbalanced because one side carries a heavy element.

## Load on demand

| Situation | Reference |
|---|---|
| Delegating the plan or the review, model choice, loop guardrails | `references/subagents.md` |
| Checklist by artifact: screen, slide, diagram, illustration | `references/review.md` |
| Calls to build, inspect, render and save in each app; dot commands | `references/apps.md` |
| Proving no edge touches a label in a dot file | `scripts/text-collisions.py` |
| Motion on top of a still | `effectcraft-motion` skill |
