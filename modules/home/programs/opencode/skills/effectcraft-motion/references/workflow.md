# Workflow: still to verified mp4

A worked path for the common job: one flat image where a part of it must move independently.

## 1. Read the asset

```sh
ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 cover.png
```

Find the split by scanning a row, do not eyeball it:

```sh
ffmpeg -v error -i cover.png -vf "crop=W:1:0:H/2" -f rawvideo -pix_fmt rgb24 - | python3 -c "
import sys
d=sys.stdin.buffer.read(); w=len(d)//3
for x in range(w):
    r,g,b=d[3*x:3*x+3]
    if g>90 and g>r+40 and g>b+20:
        print('split at', x); break
"
```

Split with ffmpeg, keep both halves at their original size:

```sh
ffmpeg -v error -y -i cover.png -vf "crop=740:810:0:0"  left.png
ffmpeg -v error -y -i cover.png -vf "crop=340:810:740:0" right.png
```

The comp background must equal the flat colour under the moving part, otherwise the hole shows when it leaves. Read it from the left half: `#101214` in the reference job.

## 2. Comp, footage, layers

```js
await tools.effectcraft.command_run({ id: "comp.new", params: {
  name: "cover-panel", width: 1080, height: 810, frameRate: 30, duration: 5, background: "#101214" } });
await tools.effectcraft.command_run({ id: "file.import", params: { paths: ["left.png", "right.png"] } });
await tools.effectcraft.command_run({ id: "layer.addItem", params: { item: 1, position: [370, 405] } });
await tools.effectcraft.command_run({ id: "layer.addItem", params: { item: 2, position: [1400, 405] } });
```

`layer.addItem` positions the layer **centre** in comp pixels. Rest position is the truth: place the moving part where it belongs at rest, then decide the off-screen value (rest x + width for a right-hand panel).

## 3. Keys

```js
await tools.effectcraft.add_keyframe({
  comp: 1, layer: 27, path: "transform/position", interpolation: "bezier",
  keys: [
    { time: 0,    value: [1400, 405] },   // off screen
    { time: 0.667, value: [910, 405] },   // at rest
    { time: 4.0,  value: [910, 405] },    // hold ends
    { time: 4.667, value: [1400, 405] }   // gone
  ]
});
```

Keys land on frames: 0.667 s is frame 20, 4.667 s is frame 140.

## 4. Ease both ends of each segment

```js
const ease = (t, side, speed, influence) => tools.effectcraft.command_run({
  id: "keys.setEase",
  params: { comp: 1, layer: 27, path: "transform/position", time: t, side, speed, influence }
});
await ease(0,     "out", 0, 8);     // arrival starts, cubic-bezier(0.08, 0, 0, 1)
await ease(0.667, "in",  0, 100);   // arrival settles
// departure mirrors the arrival: reversed bezier (1, 0, 0.92, 1) becomes 100 / 8
await ease(4.0,   "out", 0, 100);   // departure winds up
await ease(4.667, "in",  0, 8);     // departure pulls off
```

Full conversion table in `easing.md`. The influence columns swap for a mirrored exit; `scripts/ease.js` has `reverseBezier` for that.

## 5. Motion blur

```js
await tools.effectcraft.command_run({ id: "layer.setSwitch", params: { layers: [27], switch: "motionBlur", value: true } });
await tools.effectcraft.command_run({ id: "comp.setSwitch",  params: { switch: "motionBlur", value: true } });
await tools.effectcraft.command_run({ id: "comp.settings",   params: { comp: 1, shutterAngle: 180 } });
```

## 6. Verify the timing before rendering

```js
const xs = [];
for (let f = 0; f <= 20; f++) {
  const p = await tools.effectcraft.get_property({ comp: 1, layer: 27, path: "transform/position", time: f / 30 });
  xs.push(Math.round(p.value[0]));
}
// deltas expose the curve: a flat list is linear, a bell is ease-in-out, a big first drop is ease-out
console.log(xs.map((x, i) => i ? x - xs[i-1] : 0));
```

Checks that actually catch mistakes: monotonic within a segment, no motion between the hold keys, exact rest value, first and last visible frame.

## 7. Render

```js
await tools.effectcraft.command_run({ id: "renderQueue.add", params: {
  comp: 1, format: "h264", output: "/abs/path/cover-panel.mp4", quality: "best", timeSpan: "comp" } });
await tools.effectcraft.command_run({ id: "renderQueue.render", params: { wait: true } });
```

`output` is required even though the schema lists it as optional; without it the call fails with `renderVideo needs dir`. Long renders run on the CPU in headless mode.

## 8. Verify the render, not the project

```sh
ffprobe -v error -show_entries format=duration:stream=nb_frames,r_frame_rate -of default=nw=1 out.mp4
```

Measure the edge per frame in the actual pixels:

```sh
ffmpeg -v error -i out.mp4 -vf "crop=1080:2:0:400" -f rawvideo -pix_fmt rgb24 - | python3 -c "
import sys
d=sys.stdin.buffer.read(); fw=1080*3*2; n=len(d)//fw
def g(x,f):
    o=f*fw+3*x; r,gg,b=d[o:o+3]; return gg>90 and gg>r+40 and gg>b+20
for f in range(n):
    xs=[x for x in range(1080) if g(x,f)]
    print(f, '%.2fs'%(f/30), (xs[0] if xs else 'gone'))
"
```

Then report the table: frame, time, position. That is the deliverable, not "looks smooth".

## 9. Save

- `file.saveAs { path: "*.aep" }` writes the project that EffectCraft reopens.
- `file.exportAep { path, dryRun: true }` returns the loss report before you hand a file to After Effects. Render queue and footage alpha interpretation never travel; footage is linked by path.
- Contact sheet for review: `ffmpeg -i out.mp4 -vf "select='eq(n,4)+eq(n,127)',scale=320:-1,tile=2x1" -frames:v 1 sheet.png`.
