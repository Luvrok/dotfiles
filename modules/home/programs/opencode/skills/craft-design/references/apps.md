# Craft apps: calls per job

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
2. Render at the final size, not a zoomed fit.
3. Compare the two: a gap of 8 means 8 in the numbers and 8 in the pixels.
4. Look at the render as an image, not as a description of it. If the model cannot see it, say so and rely on geometry.

Do not claim a design is done from a tool's success message. A successful `add_shape` means a rectangle exists, not that it sits where it should.
