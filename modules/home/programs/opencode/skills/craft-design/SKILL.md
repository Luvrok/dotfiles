---
name: craft-design
description: Take a visual from a topic to a checked artifact in the StoryTold Craft apps: FigCraft for interfaces and mockups, VectorCraft for illustrations, logos and SVG diagrams, DeckCraft for slides, PhotoCraft for images, WordCraft for documents. Covers the brief, structure before styling, choosing the app, delegating the plan or the visual review to a subagent with a hard round limit, and verifying spacing, alignment and rendering. Use for a mockup, landing page, dashboard, component, slide deck, poster, logo, diagram, flow chart, schema, infographic, svg, "sdelaj dizajn", "primaj maket", "nabrosaj ekran", "sdelaj shemu", "oformi prezentaciyu", or any visual built with craft tools.
---

# Craft design

Design is decided before pixels: what the thing must do, for whom, in what format, and what makes it right. A canvas without a brief is decoration, and neither tool output nor a screenshot proves the result works.

## Hard rules

1. Brief before canvas: goal, audience, medium and size, content, constraints, the check that proves it good. No brief: write five lines and show them, don't start drawing.
2. Structure before style. Blocks, hierarchy and grid first; colour and type last, from a fixed token set.
3. Every number comes from a scale: spacing 4 or 8, type steps of 1.25 or 1.33, 2-3 colours plus neutrals. A one-off value is a bug unless named as one.
4. No invented content. Missing copy gets an obvious placeholder and a line in the missing list.
5. Reference, don't copy: say what is borrowed (grid, type pair, colour role), never trace.
6. Evidence is a render plus numbers. `inspect` gives geometry, `render` gives pixels; claim nothing from one alone.
7. Report measurements, not adjectives.

## Process

1. **Brief** — one paragraph plus the must-have content and 3-6 acceptance checks a reviewer could test. Ask only what neither the files nor the user can answer; everything else is a named default.
2. **References** — 2-3 real works, one line each on what is taken. No mood-board theatre.
3. **Structure** — wireframe of boxes with real text lengths; columns, margins, gutter and reading order are decided here.
4. **Tokens** — type scale with roles, spacing scale, three colour roles (background, text, accent) plus two neutrals, radius, stroke.
5. **Build** — in the app, one section per step, `inspect` after each block instead of all at the end.
6. **Check** — the checklist for the artifact type in `references/review.md`, numbers before pixels.
7. **Review** — a subagent, bounded: `references/subagents.md`.

For a large piece, show the structure and get a yes before styling. A wrong wireframe wastes every step after it.

## Choose the app

| Job | App |
|---|---|
| Screen, dashboard, landing, component, mockup | FigCraft |
| Diagram, flow, schema, logo, icon, illustration, SVG | VectorCraft |
| Slides, pitch, report deck | DeckCraft |
| Photo retouch, composite, export | PhotoCraft |
| Text document, PDF export | WordCraft |

Calls to build, inspect, render and save in each: `references/apps.md`. `list_commands` and the app's own resource are the truth about ids and parameters; don't guess them.

## Subagents

The main agent builds. A subagent either plans before or reviews after, never both, and never edits the document in the same pass.

- Plan subagent: the brief is unclear, the constraints conflict, or the piece is big enough that a wrong structure costs a rebuild.
- Review subagent: a render exists and the artifact is going to a person.
- Default budget: 2 review rounds, 5 findings per round, only P0/P1 get fixed. At the end: deliver with the open list, don't start round three.
- The reviewer checks written acceptance criteria, never "make it better". That phrase is the loop generator.

Contract, prompt templates and the anti-loop rules: `references/subagents.md`.

## What makes it look amateur

Measurable, so check it:

- Gaps between sibling blocks that differ by 1-2px; alignment that is almost a column edge.
- Type sizes from nowhere: 17, 19, 23px beside a 16px body.
- Contrast under 4.5:1 for body, under 3:1 for large text and icons.
- Equal padding that looks unbalanced because one side holds a heavy element.
- Text overflow, orphan words, three-line titles, clipped descenders.
- Diagrams: labels over lines, arrows landing inside a node, mixed node sizes, mixed stroke widths, text unreadable after scaling.

Per-artifact checklists and how to measure: `references/review.md`.

## Load on demand

| Situation | Reference |
|---|---|
| Delegating a plan or a review, loop guardrails, prompt templates | `references/subagents.md` |
| Checklist by artifact: screen, slide, diagram/SVG, illustration | `references/review.md` |
| Which calls build, inspect, render and save in each app | `references/apps.md` |
| Motion on top of a still | `effectcraft-motion` skill |
