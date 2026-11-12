// panel-slide.js - the reference job as one call. Paste after ease.js into the execute sandbox.
// Decelerate-in, hold, accelerate-out for a layer that slides in from one side.

async function panelSlide({
  comp, layer, path = "transform/position",
  restX, y, offX,
  inStart = 0, inFrames = 20, holdUntil = 4.0, outFrames = 20,
  fps = 30, bezierIn = BEZIER.house, bezierOut = null,
  shutter = 180, motionBlur = true
}) {
  const exitBezier = bezierOut || reverseBezier(bezierIn);
  const inDur = inFrames / fps;
  const outDur = outFrames / fps;
  const t1 = inStart + inDur;
  const t2 = holdUntil;
  const t3 = holdUntil + outDur;

  await tools.effectcraft.add_keyframe({
    comp, layer, path, interpolation: "bezier",
    keys: [
      { time: inStart, value: [offX, y] },
      { time: t1, value: [restX, y] },
      { time: t2, value: [restX, y] },
      { time: t3, value: [offX, y] }
    ]
  });

  // arrival: off -> rest. departure: rest -> off (signed dV handles both directions)
  await easeSegment({ comp, layer, path, tOut: inStart, tIn: t1, bezier: bezierIn, from: offX, to: restX });
  await easeSegment({ comp, layer, path, tOut: t2, tIn: t3, bezier: exitBezier, from: restX, to: offX });

  if (motionBlur) {
    await tools.effectcraft.command_run({ id: "layer.setSwitch", params: { layers: [layer], switch: "motionBlur", value: true } });
    await tools.effectcraft.command_run({ id: "comp.setSwitch", params: { switch: "motionBlur", value: true } });
    await tools.effectcraft.command_run({ id: "comp.settings", params: { comp, shutterAngle: shutter } });
  }
  return { inDur, outDur, t1, t2, t3 };
}

// verify: rest is exact, holds are flat, first/last visible frame
async function verifySlide({ comp, layer, path = "transform/position", restX, offX, frames, fps = 30 }) {
  const xs = await samplePath({ comp, layer, path, from: 0, to: frames, fps });
  const d = deltas(xs);
  const problems = [];
  if (Math.abs(xs[xs.length - 1] - offX) > 0.01) problems.push("does not end off screen");
  if (!xs.some(x => Math.abs(x - restX) < 0.01)) problems.push("never reaches rest");
  const restFrames = xs.map((x, i) => (Math.abs(x - restX) < 0.01 ? i : -1)).filter(i => i >= 0);
  if (restFrames.length < 2) problems.push("no hold detected");
  const peak = Math.max(...d.map(Math.abs));
  return { xs, deltas: d, peakPxPerFrame: peak, problems };
}

/* usage
const r = await panelSlide({
  comp: 1, layer: 27, restX: 910, y: 405, offX: 1400,
  inFrames: 20, holdUntil: 4.0, outFrames: 20, shutter: 180
});
const v = await verifySlide({ comp: 1, layer: 27, restX: 910, offX: 1400, frames: 149 });
*/
