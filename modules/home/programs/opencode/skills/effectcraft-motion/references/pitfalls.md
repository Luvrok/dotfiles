# Pitfalls

Failures met while building the reference job, with the fix. Most of them are silent, so each one needs a check, not a guess.

| Symptom | Cause | Fix |
|---|---|---|
| `no layer 27 (use a layer id...)` | the comp holding that layer is not the active one | `comp.open {comp}` first, and pass `comp` to every call anyway |
| `keys.selectAll` returns false, then `keys.delete` removes nothing | `layers` given without `comp` | pass both, then read back the key count |
| keys of a different comp vanish | `keys.delete` acts on the **active** comp's selection | check `get_project().activeComp` before any bulk key operation |
| a key is at 0.133 instead of 0.15 | keys snap to frames | choose frame counts, then divide by fps |
| easing "does nothing" | influence and speed set on the wrong side of the segment | arrival uses `out` on the first key and `in` on the second |
| motion is linear despite a bezier | `speed 0, influence 0` on both ends degenerates to linear | set a real influence on at least one side |
| the element starts moving before its key | hold key with `in` influence 100 bleeds into the next segment | use a true hold key at the departure start |
| `renderVideo needs dir` / render fails with no output | `renderQueue.add` without `output` | always pass an absolute `output` path |
| render queue empty after opening the .aep | render queue is never exported to AEP | re-add items; the report says so at export time |
| panel looks different in After Effects | footage alpha interpretation not written, footage is linked by path | `Interpret Footage` after opening, keep the PNGs at the same path |
| `importAep` reports no missing footage but frames are empty | the importer never opens files | check the real path, then Reload Footage |
| `ui_inspect` / `ui_screenshot` fail | headless session, no GUI | ignore the `ui_*` family entirely |

## PhotoCraft, for asset prep

| Symptom | Cause | Fix |
|---|---|---|
| `automation path rejected: absolute paths must be inside the automation root` | capability-scoped filesystem | use paths under the granted root, or relative ones |
| `parent traversal is not allowed` | path safety | never leave the root, not even to read |
| `automation command file.saveAs ... is disabled` | engine commands with ambient paths are disabled by design | use `doc_export` / `doc_save` instead |
| `paint.stroke` answers `not a pixel layer` | the active layer is a shape, type or group | select the pixel layer first, `layer.select {layer: 2}` |
| a parameter seems to be ignored | some commands ignore unknown keys silently | read the result back and compare, do not trust the call |
| `file.export.renderVideo` produces 31 png files | PhotoCraft exports frame sequences, not containers | encode with ffmpeg if a video is needed |

## Habit that prevents most of the above

After every edit, read the state back and compare numbers: key times, key values, rest position, key count. The engine answers happily even when it did nothing you wanted.
