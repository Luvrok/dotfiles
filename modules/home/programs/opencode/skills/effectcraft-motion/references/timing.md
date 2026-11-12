# Timing and spacing

Duration says weight: fast is light, slow is heavy. If every move is 300 ms, nothing has weight.

## Frames first

Pick the frame count, then convert. At 30 fps one frame is 33.3 ms; keyframes snap to the nearest frame, so `0.15 s` silently becomes `0.133` or `0.167`.

| Seconds | Frames at 30 fps |
|---|---|
| 0.10 | 3 |
| 0.20 | 6 |
| 0.30 | 9 |
| 0.50 | 15 |
| 0.67 | 20 |
| 1.00 | 30 |

Below 3 frames a move reads as a cut, which is a valid style but say so out loud.

## Durations

| Element | Arrival | Departure | Note |
|---|---|---|---|
| Small label, chip, badge | 3-4 frames | 2-3 frames | distance under 40 px |
| Panel, card, side bar | 6-9 frames | 4-6 frames | distance 120-400 px |
| Full-frame wipe, hero | 12-20 frames | 8-12 frames | one element only |
| Camera-like push | 20-30 frames | 12-20 frames | needs deep space to read |

Two anchors that hold up in practice: a panel crossing a third of the frame wants 6 to 9 frames, and anything with a long decelerate tail wants 18 to 22 frames total even if it visually lands early.

Departure is 60 to 80 percent of arrival. An exit the same length as the entrance feels reluctant.

## Holds

- Hold the settled state long enough to read: 1.5 s minimum for a price, 2.5 s for text to be read twice.
- The last frame of the comp should be a legible frame, not a blur.
- A hold is a hold: two keys of equal value with any interpolation in between produce the same pixels, but a hold key states intent and survives someone retiming the segment.

## Motion blur

| Shutter | Blur at 30 fps | Use |
|---|---|---|
| 200-360 degrees | wide streak, text smears | fast whips with no small type |
| 180 degrees | half a frame of travel | default |
| 90-120 degrees | crisp edge with speed | panels carrying text |
| 0 | no blur | mechanical, UI, transitions meant to feel digital |

Peak speed matters more than shutter. Anything above roughly 40 px per frame smears small text; above 100 px per frame even a headline turns into a streak. Measure the peak delta before blaming the shutter.

## Stagger

If two elements move, offset them by 2 to 4 frames and keep the same easing. Simultaneous motion is only right when simultaneity is the point, such as a panel and its shadow leaving together.

## Comp length

Length is not a style choice, it is a budget: arrival + hold + departure + tail. Compute it before adding the last key. A 5 second comp with a 0.67 s arrival and a 0.67 s exit holds for 3.66 s; if that feels long, the hold is what to cut, not the easing.
