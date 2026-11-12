// ease.js - paste into the execute sandbox (Code Mode), then call the helpers.
// The math is verified against the engine: the sampled path matches the analytic bezier.

const BEZIER = {
  outSine:   [0.61, 1, 0.88, 1],
  outQuad:   [0.50, 1, 0.89, 1],
  outCubic:  [0.33, 1, 0.68, 1],
  outQuart:  [0.25, 1, 0.50, 1],
  outQuint:  [0.22, 1, 0.36, 1],
  outExpo:   [0.16, 1, 0.30, 1],
  inQuad:    [0.11, 0, 0.50, 0],
  inCubic:   [0.32, 0, 0.67, 0],
  inQuart:   [0.50, 0, 0.75, 0],
  inExpo:    [0.70, 0, 0.84, 0],
  inOutCubic:[0.65, 0, 0.35, 1],
  inOutQuart:[0.76, 0, 0.24, 1],
  house:     [0.08, 0, 0, 1],   // the panel preset
  m3Std:     [0.20, 0, 0, 1],
  m3StdDec:  [0.00, 0, 0, 1],
  m3StdAcc:  [0.30, 0, 1, 1],
  m3EmphDec: [0.05, 0.70, 0.10, 1],
  m3EmphAcc: [0.30, 0, 0.80, 0.15]
};

// cubic-bezier -> { out:{influence,speed}, in:{influence,speed} } for a move of dV over T seconds
function easeFromBezier(bezier, dV, T) {
  const [x1, y1, x2, y2] = bezier;
  const k = dV / T;
  return {
    out: { influence: x1 * 100, speed: x1 === 0 ? 0 : (y1 / x1) * k },
    in:  { influence: (1 - x2) * 100, speed: x2 === 1 ? 0 : ((1 - y2) / (1 - x2)) * k }
  };
}

// the same curve played backwards, for a departure that mirrors an arrival
function reverseBezier([x1, y1, x2, y2]) { return [1 - x2, 1 - y2, 1 - x1, 1 - y1]; }

// write both ends of one segment; times are layer seconds
async function easeSegment({ comp, layer, path, tOut, tIn, bezier, from, to }) {
  const e = easeFromBezier(bezier, to - from, tIn - tOut);
  const call = (time, side, v) => tools.effectcraft.command_run({
    id: "keys.setEase",
    params: { comp, layer, path, time, side, speed: v.speed, influence: v.influence }
  });
  await call(tOut, "out", e.out);
  await call(tIn, "in", e.in);
  return e;
}

// analytic curve, for comparing against the engine
function bezierAt(bezier, u) {
  const [x1, y1, x2, y2] = bezier;
  let lo = 0, hi = 1;
  for (let i = 0; i < 50; i++) {
    const m = (lo + hi) / 2;
    const bx = 3 * (1 - m) ** 2 * m * x1 + 3 * (1 - m) * m * m * x2 + m ** 3;
    if (bx < u) lo = m; else hi = m;
  }
  const t = (lo + hi) / 2;
  return 3 * (1 - t) ** 2 * t * y1 + 3 * (1 - t) * t * t * y2 + t ** 3;
}

// read one property per frame; returns the values
async function samplePath({ comp, layer, path, from, to, fps = 30, dim = 0 }) {
  const out = [];
  for (let f = from; f <= to; f++) {
    const p = await tools.effectcraft.get_property({ comp, layer, path, time: f / fps });
    out.push(dim === null ? p.value : p.value[dim]);
  }
  return out;
}

function deltas(xs) { return xs.map((x, i) => (i ? +(x - xs[i - 1]).toFixed(1) : 0)); }
