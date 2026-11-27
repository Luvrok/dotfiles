# Apps: calls per job

## Graphviz (default for diagrams)

Plain text source, reproducible render, and a diff for every change. Keep the `.dot` next to the render in the vault.

```
dot -Tsvg  hosts.dot -o hosts.svg          # the file the note embeds
dot -Tpng -Gdpi=192 hosts.dot -o hosts.png # 2x, for sending around
dot -Tpng -Gdpi=72  hosts.dot -o /tmp/check.png  # 1:1 with the viewBox
dot -Tplain hosts.dot                      # geometry: canvas, boxes, splines
```

Check from `-Tplain`: the canvas in inches ×72 = points, node boxes must not overlap, nothing sits outside the canvas. Text is a separate pass: `scripts/text-collisions.py hosts.dot` treats each label as a box, prints `THROUGH the box` when an edge enters it, and fails under 8pt clearance. `-Tplain` has no cluster titles, so the script is the only check that sees an arrow inside a caption.

Rules that keep a dot file legible: one idea per block, `rank=same` orders a row but only with invisible edges between the nodes, cluster labels stay short, and after two failed layouts change the layout engine or the tool, not `nodesep`.

## Craft apps

General: the app's command list is the truth for ids and parameters. Inspect gives geometry, render gives pixels. Save last, into `~/HOME/wizzard/Holocron/9-files/`. Show the exported png/svg/pdf to the user with `browser.preview` — it opens in the Review pane.

| App | Build | Inspect | Render | Save |
|---|---|---|---|---|
| FigCraft | `create_node`, `set_properties`, `run_command`, `batch` | `inspect_document`, `get_node` | `screenshot` | file command |
| VectorCraft | `draw_shape`, `draw_path`, `set_paint`, `command_run` | `doc_inspect` | `render_preview` | file command |
| DeckCraft | `new_presentation`, `add_slide`, `add_shape`, `add_text_box`, `insert_picture`, `insert_chart` | `inspect_slide` | `render_slide` | `save_presentation` |
| PhotoCraft | `doc_new`, `doc_open`, `command_run` | `doc_inspect` | `render_preview` | `doc_save` |
| WordCraft | `new_document`, `type_text`, `execute` | `inspect_document` | `render_page` | `save` |
| EffectCraft | see the `effectcraft-motion` skill | `doc_inspect` | `render_preview` | render queue |

## Notes

- **FigCraft**: page units are pixels, y down. Children take x/y relative to the parent; auto-layout frames place their children, so set layout, gap, padding and sizing instead of coordinates. Screenshot the page or specific layers.
- **VectorCraft**: document coordinates in points, y down, a new document is 612x792. Commands act on the selection unless given `ids`; new objects become the selection.
- **DeckCraft**: a slide is 960x540 by default, coordinates are points on the slide. Shape ids belong to the current slide.
- **PhotoCraft / VectorCraft / DeckCraft / WordCraft / PDFCraft / SoundCraft / EffectCraft**: read and write only under the `9-files` roots. A path outside is refused, not a bug.
- **Files**: `.figcraft`, `.vectorcraft`, `.deckcraft`, `.pcraft` are native and reopen; `.svg`, `.png`, `.pptx`, `.pdf`, `.docx` are exports for the user.

## Verify a build

1. `inspect` after each block: bounds, sizes, fills, text.
2. Render at the final size, and also at the size the reader sees (a note is ~700-800px wide, a slide 1920).
3. Compare the two: a gap of 8 means 8 in the numbers and 8 in the pixels.
4. Run the collision pass: node × node, node × label, edge × label, label × label. A node-only check reports zero overlaps on a picture with a line through a caption.
5. Look at the render as an image, not as a description of it. If the model cannot see it, say so and rely on geometry.

Do not claim a design is done from a tool's success message. A successful `add_shape` means a rectangle exists, not that it sits where it should.
