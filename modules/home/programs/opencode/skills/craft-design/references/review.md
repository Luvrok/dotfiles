# Review by artifact

Measure, don't eyeball. Read bounds and fills from inspect, compute the gaps and ratios, then look at the render to confirm. A finding is a number and a criterion; anything else is taste and goes to P2.

## Universal, in this order

1. **Content** — every required text present, no placeholder or lorem left, spelling and capitalisation consistent, numbers agree with their source.
2. **Geometry** — alignment, gaps from the scale, equal margins, no overlap, nothing outside the format, nothing clipped.
3. **Collisions** — node × node, node × label, edge × label, label × label, cluster title × edge. A node-only check is not a collision check.
4. **Type** — sizes from the scale, line-height, orphans, truncation, three-line titles.
5. **Contrast** — body text 4.5:1, large text (>= 24px or 18.66px bold) 3:1, non-text UI 3:1.
6. **Render** — final size, 100%, and the size the reader sees (note ~700-800px, slide 1920); compare with the geometry, look for clipping and fallback fonts.
7. **States** — if it is interactive or has data: long text, empty, error, loading.

## Screen (FigCraft)

- Every element on a column, or off it on purpose.
- Sibling blocks share one gap value; sections separated by a larger step from the same scale.
- One primary action, one H1, at most three levels of hierarchy.
- Body 14-16px, line-height 1.4-1.6, measure 65-75 characters.
- Targets >= 44px, icon-to-label gap on the 8px grid, icon stroke consistent.
- Muted and disabled text still readable (or unmistakably disabled).
- Text containers without a fixed height; the longest real string tested.
- Real images, correct aspect ratio, none stretched; no grey placeholder left.

## Slide (DeckCraft)

- One idea per slide. The title states the claim, not the topic.
- Title to body ratio at least 2:1; body >= 18-20pt in a 960x540 deck.
- Safe margin >= 40-48pt; nothing within 20pt of the edge.
- At most 6 bullets, at most 12 words each. A paragraph from a document is a failed slide.
- Title position, footer and page numbers identical across slides.
- A diagram where a diagram is faster to read than the sentence.
- The last slide is a decision or an ask, not "thank you".

## Diagram / SVG (VectorCraft)

- `viewBox` and export size set; text readable at the size it will be viewed, not only at 400%.
- Text stays text unless outlines are required; no non-uniform scaling of text.
- Labels >= 12px at 100%, no label over a line, no two labels touching, no edge inside a label box, no edge crossing a cluster title. Confirmed by the reviewer on the render; `scripts/text-collisions.py` is an optional pre-check.
- Arrows start and end on node borders, arrowheads visible, nothing pointing into empty space.
- One reading direction per row: left-to-right or top-to-bottom, not both.
- Node sizes consistent per level, stroke widths consistent per level.
- Crossings minimised; where two lines must cross, one gets a gap or bridge.
- Legend when there are more than two colours or shapes; colours distinguishable in greyscale.
- No shadow, blur or 3D unless it carries meaning.
- Grep the exported SVG for `viewBox`, leftover `<text>` with a missing font, and `transform="scale(` on text.

## Illustration / logo

- Silhouette test: fill it black, shrink to 16px, it still reads.
- One idea. Details that vanish when shrunk get removed.
- Stroke weights consistent; optical centring, not geometric.
- Palette from the token set; no gradient unless the brief asks for one.
- A logo works on dark and light, in one colour, with clearspace at least the height of its counter.

## Report

```
id | severity | criterion | measured deviation | where
```

End with the verdict and the count. A review that lists only adjectives ("feels crowded") is not usable: ask for the gap values and the margins.
