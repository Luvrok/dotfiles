# Easing

## Two directions, two families

| Direction | Family | Reads as | Wrong choice looks like |
|---|---|---|---|
| Arrival (incoming) | ease-out, decelerate | fast entry, long settle | a slide transition that hesitates |
| Departure (outgoing) | ease-in, accelerate | rests, then gets pulled off | something sliding away and stopping |
| Both inside the frame | ease-in-out, standard | symmetric, calm | inertia with no reason |

The pattern this skill was built around is a **decelerate-in, hold, accelerate-out slide**: an element arrives with a hard ease-out, holds still, then leaves with a mirrored ease-in. In Material terms the two halves are "emphasized decelerate" and "emphasized accelerate". In UI-motion slang: a panel slide, or a hero snap-in. It is the default for covers, banners and price cards.

## Cubic-bezier to key values

EffectCraft, like After Effects, shapes a segment with a handle at each end: `influence` in percent of the segment duration, and `speed` in units per second. Given `cubic-bezier(x1, y1, x2, y2)` and a change of `dV` units over `T` seconds:

```
out.influence = x1 * 100
out.speed     = (y1 / x1) * (dV / T)
in.influence  = (1 - x2) * 100
in.speed      = ((1 - y2) / (1 - x2)) * (dV / T)
```

`speed` is signed along the value axis: positive when the value grows. For a panel moving right to left, `dV` is negative and so is the speed.

Worked example, panel from x=1400 to x=910 over 0.667 s with `cubic-bezier(0.08, 0, 0, 1)`:

```
dV = -490 px, T = 0.667 s, dV/T = -735 px/s
out: influence 8,   speed (0/0.08)   * -735 = 0
in:  influence 100, speed ((1-1)/(1-0)) * -735 = 0
```

That is the whole conversion. Verified in the engine: sampling the result every frame reproduces the analytic curve to the pixel.

### Reversing a curve

A departure that mirrors an arrival is the same curve played backwards: `cubic-bezier(1 - x2, 1 - y2, 1 - x1, 1 - y1)`.

The house preset `(0.08, 0, 0, 1)` reverses to `(1, 0, 0.92, 1)`. Through the formula that is `out influence 100, out speed 0` and `in influence 8, in speed 0`. Skip the reversal and the exit decelerates into the frame edge, which reads as the panel sliding away and parking there instead of leaving.

## Preset table

Arrival presets, `k = dV / T`:

| Name | cubic-bezier | out influence | out speed | in influence | in speed |
|---|---|---|---|---|---|
| outSine | 0.61, 1, 0.88, 1 | 61 | 1.64 k | 12 | 0 |
| outQuad | 0.5, 1, 0.89, 1 | 50 | 2.00 k | 11 | 0 |
| outCubic | 0.33, 1, 0.68, 1 | 33 | 3.03 k | 32 | 0 |
| outQuart | 0.25, 1, 0.5, 1 | 25 | 4.00 k | 50 | 0 |
| outQuint | 0.22, 1, 0.36, 1 | 22 | 4.55 k | 64 | 0 |
| outExpo | 0.16, 1, 0.3, 1 | 16 | 6.25 k | 70 | 0 |

Departure presets are the mirror: swap the influence columns, negate `k`, and use the ease-in row.

| Name | cubic-bezier | out influence | out speed | in influence | in speed |
|---|---|---|---|---|---|
| inQuad | 0.11, 0, 0.5, 0 | 11 | 0 | 50 | 2.00 k |
| inCubic | 0.32, 0, 0.67, 0 | 32 | 0 | 33 | 3.03 k |
| inQuart | 0.5, 0, 0.75, 0 | 50 | 0 | 25 | 4.00 k |
| inExpo | 0.7, 0, 0.84, 0 | 70 | 0 | 16 | 6.25 k |

Symmetrical, for a move that starts and ends on screen:

| Name | cubic-bezier | out influence | in influence |
|---|---|---|---|
| inOutCubic | 0.65, 0, 0.35, 1 | 65 | 65 |
| inOutQuart | 0.76, 0, 0.24, 1 | 76 | 76 |

## Material 3 tokens

M3 has moved to springs in the expressive update; these are its legacy cubic-bezier tokens and they still match most UI specs.

| Token | cubic-bezier | Use |
|---|---|---|
| standard | 0.2, 0, 0, 1 | elements that start and end on screen |
| standardDecelerate | 0, 0, 0, 1 | incoming |
| standardAccelerate | 0.3, 0, 1, 1 | outgoing |
| emphasizedDecelerate | 0.05, 0.7, 0.1, 1 | incoming hero or panel |
| emphasizedAccelerate | 0.3, 0, 0.8, 0.15 | outgoing hero |
| linear | 0, 0, 1, 1 | readouts only |

`standardDecelerate` has x1 = 0, so the formula divides by zero: write `influence 0, speed 0` and check the sample. Influence 0 means an instantaneous velocity jump, which is legal but harsh.

## House preset

The verified panel preset is `cubic-bezier(0.08, 0, 0, 1)`: a touch of initial velocity compared to M3 standardDecelerate, and a very long tail. At 30 fps it spreads over 20 frames, reaches half the distance in about 3 frames and 90 percent in 11. Use it for covers and cards when the client asks for something that "feels expensive".

Aggressive variant: `cubic-bezier(0.16, 1, 0.3, 1)` (outExpo) spends 60 percent of the path in the first frame at 30 fps, which is a wipe rather than a slide. Only for elements wider than a third of the frame.

## Anti-patterns

- Ease-in-out on an entrance: the element creeps, then rushes. Name it when reviewing.
- Identical durations on entry and exit: the exit should be 60 to 80 percent of the entry unless the brief says otherwise.
- Overshoot on text: the glyphs smear against motion blur. Bounce is for physical objects, not for panels.
- Long tails over 0.8 s: the motion is over but the frame is not, so the eye waits.
- Easing a segment whose values are equal: harmless, but if a hold needs to be a true hold, make it a hold key, not an eased flat segment.
