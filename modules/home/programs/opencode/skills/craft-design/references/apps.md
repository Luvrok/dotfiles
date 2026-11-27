# App workflows

Tool names and parameters can change. Treat the current command list, tool descriptions, and app state as the source of truth; discover commands before calling them. Inspect returns structure and geometry, while a render shows the pixels.

## Graphviz

Keep the `.dot` source with the exported render when reproducibility matters. Common checks:

```sh
dot -Tsvg diagram.dot -o diagram.svg
dot -Tpng -Gdpi=192 diagram.dot -o diagram.png
dot -Tplain diagram.dot
```

Use plain output to check canvas and node geometry; view the SVG/PNG at its actual reading size to check labels, clipping, and edge collisions. If Graphviz is unavailable, follow the machine's package/tooling instructions rather than assuming it is installed.

## Craft apps

| App | Build | Inspect | Render | Save/export |
|---|---|---|---|---|
| FigCraft | `create_node`, `set_properties`, `run_command`, `batch` | `inspect_document`, `get_node` | `screenshot` | Discover the file command |
| VectorCraft | `draw_shape`, `draw_path`, `set_paint`, `command_run` | `doc_inspect` | `render_preview` | Discover the file command |
| DeckCraft | `new_presentation`, `add_slide`, `add_shape`, `add_text_box`, `insert_picture`, `insert_chart` | `inspect_slide` | `render_slide` | `save_presentation` |
| PhotoCraft | `doc_new`, `doc_open`, `command_run` | `doc_inspect` | `render_preview` | `doc_save` |
| WordCraft | `new_document`, `type_text`, `execute` | `inspect_document` | `render_page` | `save` |
| PDFCraft | `doc_open`, page/document commands | `doc_info`, `text_extract` | `page_render` | `doc_save` |
| EffectCraft | See `effectcraft-motion` | `doc_inspect` | `render_preview` | Render queue or discovered export command |

Use the app's supported paths and formats. Do not assume all apps share a save root or that every tool has filesystem access. Preview the exported artifact for the user only when a suitable preview tool is available and its instructions have been loaded.

## Useful checks

- **FigCraft:** page coordinates are pixels; child positions are relative to the parent. Auto-layout frames position children, so configure layout, gap, padding, and sizing instead of forcing coordinates.
- **VectorCraft:** document coordinates are points, y increases down, and commands may act on the current selection unless ids are supplied.
- **DeckCraft:** the default slide is 960×540 points; shape ids belong to the current slide.
- Verify a representative section during a larger build, then inspect and render the final output. Compare measured geometry with the rendered result where both are available.
