# Subagents: design and review

Two roles, never the same subagent: one owns the design, another reviews the render.

## Design subagent

The design subagent chooses the plan, composition, visual language and level of detail. The main agent gives it the brief, verified facts and constraints, and does not pre-decide layout or styling.

- Brief it with purpose, audience, output format and size, required content, verified facts and sources, constraints (tool, house style, format, accessibility), acceptance criteria and available tools.
- It states the design intent and plan, builds the artifact, and inspects the render itself. When the app tools are unavailable, it returns a concrete, executable build plan instead and the main agent runs that plan unchanged.
- It fills missing choices with sensible defaults and states them. It asks only when a choice would materially change the result.
- It does not invent factual claims or requested copy. Unknowns are marked unverified.
- Keep the designer and the reviewer separate. The designer applies the review findings and renders again.

## Design prompt

```text
You are the design subagent for a visual artifact. You own the plan,
composition, visual language and detail choices; do not ask the main agent to
choose them.

Brief: <purpose, audience, output format and size, required content>
Facts and sources: <verified facts, files to check, what not to invent>
Constraints: <tool, house style, format, accessibility, size>
Acceptance criteria: <testable criteria>
Available tools: <apps or commands>

1. State the design intent and plan: content order, hierarchy, layout,
   encoding, palette, type scale, level of detail.
2. Build the artifact. If the app tools are unavailable, return a concrete,
   executable build plan instead.
3. Render and inspect the result yourself.
4. Report: decisions with rationale, files changed, what you checked, any
   unverified facts or open questions.
```

## Independent visual review

For a non-trivial visual composition, use a separate reviewer after the first complete render. The designer may be strong at code and tool operations but miss visual defects; the reviewer's job is to inspect the artifact as an image and turn defects into concrete changes.

### Choose and brief the reviewer

- Use an independent subagent when delegation is allowed by the applicable instructions. The designer must not review its own render; the visual review is the separation.
- Prefer a currently available chat model that can inspect images, rather than automatically reusing the builder model. Do not infer vision capability from a model's name. If capability cannot be established, say the review is not a visual pass.
- Give the reviewer the actual rendered image or a path/tool it can open, plus the brief, acceptance criteria, intended viewing size, and relevant inspect data or element ids. A text description of the render is not a substitute for the image.
- The reviewer is read-only. It identifies fixes; the design subagent applies them and produces the next render. This keeps the reviewer independent of its own changes.

### Reviewer prompt

```text
You are an independent visual reviewer. Inspect the actual rendered artifact
against the brief, acceptance criteria, and review checklist below. Do not edit
the artifact or suggest unrelated redesigns.

Brief: <brief>
Acceptance criteria: <testable criteria>
Artifact/render: <image or accessible path and app>
Intended viewing size: <size/use>
Inspect data and element ids: <relevant bounds, text, ids>

Look specifically for visual failures such as arrows or edges entering labels,
text outside its container, clipping, inconsistent alignment or spacing,
poor hierarchy, and unreadable contrast. Report only findings supported by the
image, inspect data, or a stated criterion. For each, give an exact proposed
change (element/id and what to move, resize, or restyle); give coordinates or
dimensions when the evidence supports them. Avoid vague advice like "make it
cleaner".

Return up to 5 findings, highest severity first:
id | severity | element/location | evidence and criterion | exact proposed change

P0: wrong content, unreadable text, clipping, or a defect that blocks use.
P1: clear, fixable violation of an acceptance criterion.
P2: optional polish or taste, not a blocker.

End with: VERDICT: PASS | FIX (P0: n, P1: n)
Unverified checks: <list, or none>
```

## Apply and confirm

1. The design subagent applies supported P0/P1 findings; when the main agent executes the designer's build plan, it applies them there. If a recommendation is not supported by the brief or evidence, reject it with a short reason; do not silently change requirements.
2. Render the changed artifact again and ask the reviewer to check the changed areas plus any previous unresolved P0/P1 findings.
3. Use at most two review rounds by default. If serious findings remain, report them rather than looping indefinitely. P2 is optional polish unless the user asks for it.
4. If the reviewer could not see the image, report that the visual pass was skipped. Geometry-only feedback can still be useful, but is not a PASS on arrows, text overflow, or spacing appearance.
