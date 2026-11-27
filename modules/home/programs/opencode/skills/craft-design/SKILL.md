---
name: craft-design
description: Create or revise visual artifacts with StoryTold Craft apps or Graphviz. Covers brief, tool choice, design, building, and proportionate visual verification. Use for interfaces, mockups, slides, illustrations, logos, diagrams, infographics, SVGs, макеты, схемы, презентации, and other visual work made with Craft tools or dot.
---

# Craft design

Make the artifact serve its purpose, not the process. Match the amount of planning and checking to the task; preserve the user's requested tool, format, and constraints.

## Workflow

1. **Brief.** Establish purpose, audience, output format/size, required content or assets, constraints, and what counts as done. Ask only about missing choices that would materially change the result; otherwise use and state sensible defaults.
2. **Choose a tool.** Follow the user's choice. If none was given, use the table below. Offer alternatives only when the choice is genuinely ambiguous and has a meaningful trade-off.
3. **Design.** Decide the content order, hierarchy, layout, visual encoding, typography, palette and level of detail before building. Fill missing choices with sensible defaults and state them. Ask only when a choice would materially change the result.
4. **Build.** Discover the current app commands and parameters before relying on them. Work in meaningful sections and inspect intermediate results when that helps catch costly mistakes.
5. **Visual review.** For a non-trivial visual composition, review the actual render against the brief and `references/review.md`: check the pixels, not just the geometry. A successful tool call proves only that the command ran. Fix what the review finds and render again; at most two review rounds, then report remaining findings rather than looping. If no render is available, say so and do the best available check without calling it a visual pass.
6. **Deliver.** Save or export in the requested format and location, and report any missing content, limitations, or unverified facts.

## Principles

- Do not invent factual claims or requested copy. Verify facts against user-provided sources; otherwise mark them unverified or ask. Creative content can be original when the brief permits it.
- Build hierarchy and structure before decorative styling. Use a consistent spacing, type, and colour system appropriate to the artifact rather than forcing one scale on every format.
- Make text readable and keep labels clear of edges, shapes, and other labels. Check contrast where text and colour choices are part of the deliverable.
- A successful tool call proves only that the command ran. Inspect or render the result before saying the artifact is ready.
- Follow higher-priority instructions and the tool's current access limits. User-selected app choices take precedence. Do not silently redesign the artifact: a change of a stated design decision is a conscious revision, recorded in the report.

## Choose the app

| Artifact | Good default | Use another tool when |
|---|---|---|
| Diagram, graph, network, schema, flow | Graphviz (`.dot`) | The result needs hand-drawn detail or precise one-off illustration: VectorCraft |
| Screen, dashboard, landing page, component, mockup | FigCraft | The user requests another format/tool |
| Slides or presentation | DeckCraft | The user requests another format/tool |
| Photo retouch or composite | PhotoCraft | — |
| Text document | WordCraft | — |
| PDF inspection/editing | PDFCraft | — |
| Animation | EffectCraft | Use the `effectcraft-motion` skill |

Graphviz is a strong default for repeatable, data-driven diagrams because the source is diffable and the render reproducible. It is not automatically best for every visual.

## Load on demand

| Situation | Reference |
|---|---|
| Build, inspect, render, and save with each app; Graphviz | `references/apps.md` |
| Artifact-specific quality checks | `references/review.md` |
| Motion on top of a still | `effectcraft-motion` skill |
