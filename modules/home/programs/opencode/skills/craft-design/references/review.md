# Review by artifact

Review against the brief and acceptance criteria, not personal taste. Measure values when the app exposes them; use the render to check what geometry cannot prove. Scale the depth of review to the artifact and the cost of an error.

## Common checks

1. **Content:** required content is present; no unintended placeholders, clipping, or unsupported factual claims.
2. **Hierarchy:** the primary message or action is easy to find; grouping and reading order are clear.
3. **Geometry:** alignment, spacing, margins, bounds, and overlaps fit the format.
4. **Text and contrast:** labels are legible at intended size, not obscured by edges or shapes; check contrast when relevant. WCAG contrast targets are 4.5:1 for normal text and 3:1 for large text and meaningful UI graphics.
5. **Render:** inspect the final artifact at its intended viewing size when rendering is available; look for clipping, font substitution, and details that disappear when scaled down.
6. **States:** for interactive or data-driven work, check relevant long-content, empty, loading, and error states when they are in scope.

Record findings with a location, the violated criterion, and a measurement or concrete example where possible. A simple severity scheme can help prioritize: P0 blocks use or makes content wrong; P1 is a clear criteria failure; P2 is optional polish. Do not present an unperformed visual check as passed.

## Screen or interface

- Check the main task, primary action, and information hierarchy.
- Check alignment, repeated spacing, responsive/content bounds, and target sizes against the brief and platform.
- Test the longest realistic label and content when text wrapping matters.
- Confirm images keep their aspect ratio and placeholders are intentional.

## Slide or presentation

- Keep one main point per slide; titles should communicate the point when the brief allows.
- Check text size, contrast, safe margins, consistent repeated elements, and slide-to-slide rhythm.
- Split dense copy or data when the audience cannot read it at presentation size.

## Diagram, graph, or SVG

- Check reading direction, node/edge relationships, and whether arrows start/end at the intended objects.
- Ensure labels remain readable and clear of lines, nodes, and cluster titles.
- Check crossings, legend needs, consistent visual encoding, and SVG viewBox/export bounds.
- Inspect the SVG source when useful for missing text, fonts, or unintended transforms.

## Illustration or logo

- Check silhouette and recognizability at the smallest intended size.
- Check stroke consistency, optical balance, and contrast on intended backgrounds.
- For a logo, verify one-colour and light/dark use when those variants are in scope.

## Findings format

```text
id | severity | criterion | evidence or measured deviation | location
```

End with a short verdict and any checks that remain unverified.
