# Independent visual review

For a non-trivial visual composition, use a separate reviewer after the first complete render. The builder may be strong at code and tool operations but miss visual defects; the reviewer's job is to inspect the artifact as an image and turn defects into concrete changes.

## Choose and brief the reviewer

- Use an independent subagent when delegation is allowed by the applicable instructions. Planning can stay in the main session; the visual review is the important separation.
- Prefer a currently available chat model that can inspect images, rather than automatically reusing the builder model. Do not infer vision capability from a model's name. If capability cannot be established, say the review is not a visual pass.
- Give the reviewer the actual rendered image or a path/tool it can open, plus the brief, acceptance criteria, intended viewing size, and relevant inspect data or element ids. A text description of the render is not a substitute for the image.
- The reviewer is read-only. It identifies fixes; the main agent applies them and produces the next render. This keeps the reviewer independent of its own changes.

## Reviewer prompt

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

1. Apply supported P0/P1 findings in the main session. If a recommendation is not supported by the brief or evidence, reject it with a short reason; do not silently change requirements.
2. Render the changed artifact again and ask the reviewer to check the changed areas plus any previous unresolved P0/P1 findings.
3. Use at most two review rounds by default. If serious findings remain, report them rather than looping indefinitely. P2 is optional polish unless the user asks for it.
4. If the reviewer could not see the image, report that the visual pass was skipped. Geometry-only feedback can still be useful, but is not a PASS on arrows, text overflow, or spacing appearance.
