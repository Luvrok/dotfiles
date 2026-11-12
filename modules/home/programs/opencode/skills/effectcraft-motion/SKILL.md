---
name: EffectCraft Motion
description: Make motion in EffectCraft (After Effects class) over MCP instead of by hand. Covers comp setup, keyframe easing from real cubic-bezier numbers, slide and fade panel reveals, motion blur, per-frame verification, and mp4 delivery. Use for anything animated from a still: cover or banner animation, panel in and out, bumper, 5 second loop, titry, animatsiya oblozhki, "sdelaj animatsiyu", prichod i uchod, easing, bizie, keyframes, motion blur, render mp4, or when an exported .aep must open correctly in After Effects.
---

# EffectCraft motion

Animation is two decisions: when things happen, and how values distribute between those moments. Both are design, neither has a safe default.

This skill drives EffectCraft through its MCP tools. For stills and asset prep use PhotoCraft, for cutting clips together use FilmCraft.

## Hard rules

1. Entrances decelerate, exits accelerate. Ease-out on arrival, ease-in on departure. Ease-in-out reads as a PowerPoint slide; use it only when a move both starts and ends inside the frame.
2. Linear only for machine readouts, counters, progress bars. Never for a panel.
3. No bounce, overshoot or spring unless asked by name. `back` and `elastic` curves stay off by default.
4. Rest is exact. A layer lands on its final value, not near it. Verify pixels, not keyframe values.
5. Easing is influence and speed per key, not a curve name. Convert from cubic-bezier and check the sampled path.
6. Motion blur is style, not a default on everything. 180 degrees of shutter is the baseline; drop to 120 when small text smears.
7. One thing moving well beats five moving adequately. If a motion can be removed without hurting the message, remove it.
8. Report numbers, not adjectives: durations in seconds and frames, peak px per frame, first and last frame the element is visible.

## Load on demand

| Situation | Reference |
|---|---|
| Choosing or critiquing easing, naming the pattern, converting bezier to keys | `references/easing.md` |
| Durations, holds, fps, frame snapping, blur angles | `references/timing.md` |
| Full recipe from a still to a verified mp4 | `references/workflow.md` |
| Tool errors, silent no-ops, AEP export losses | `references/pitfalls.md` |
| Ready-made keyframe builder and curve sampler | `scripts/ease.js`, `scripts/panel-slide.js` |

## The loop

1. **Read the asset.** Size, where the split is, what moves independently. Split before animating; never animate one half of a flat image on top of itself.
2. **Comp matches the asset.** Same size, 30 fps, duration in whole frames.
3. **Place layers at rest first.** The final position is the truth; animate out from it.
4. **Key the timing.** Arrival start, arrival end, hold, departure start, departure end. Times snap to frames, so pick frame numbers, not decimals.
5. **Ease each segment.** Convert the bezier to influence and speed, write both ends of the segment.
6. **Verify by sampling.** Read the property every frame, print deltas, check monotonic, check the rest value is exact. A still frame is not evidence of timing.
7. **Render and re-verify.** Measure the rendered pixels, not only the project: edge position per frame, first and last visible frame.

## Tool map

| Task | Tool |
|---|---|
| Inspect project, comps, footage | `get_project`, `get_comp`, `doc_inspect` |
| Discover a command and its params | `list_commands`, `describe_command` |
| Run anything | `command_run`, `command_batch` |
| Keyframes | `add_keyframe`, `get_property`, `prop.addKey` |
| Easing | `command_run` with id `keys.setEase` |
| Look at a frame | `render_preview`, `render_frame` |
| Deliver | `renderQueue.add` then `renderQueue.render`, `file.saveAs`, `file.exportAep` |

Headless mode has no GUI: `ui_*` tools and anything needing bridge mode fail. Skip them.
