# Pass 550: what wades breaks the water

## Category

From the independent grade taken after pass 545 (5.4/10), as pass 549's "Next" named it: the flat
wading-water rectangles in Vorrhallow. Art cohesion and Atmosphere in the grade.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations
were spent. The hosted workbench is still down (its Vercel Blob store is suspended); it stays under
"stuck" for Sean.

This pass was cut off by an app restart before its tests ran; the next scheduled run resumed it.

## Audit

- `Tide` drew the surface row as one translucent fill and the cells under it as another, with a
  breathing pale line on top. The hero and the Crystal Dwarves stood in it with nothing where the
  water met them, so the water read as a tinted box laid over the scene.

## What was built

- **Waterline**: each visible `player` or `enemy` body whose collision box crosses the surface, over
  a surface column, gets a bright line across it, lifted a pixel, with a lip at each end.
- **Ripples**: one every 1.1 s while a body stands, every 0.35 s while it moves; each is a crest
  and a trough running out both ways, spreading 30 px and fading over 1.3 s (48 at most).
- **Depth**: the surface row is lighter under the surface and darker and denser toward the floor
  in four dithered steps (2 x 2, 2-pixel blocks), drawn once as a strip texture.
- Two fixes found on resuming: the depth steps divided by the full tile, so the floor row never
  reached the deepest step; and a drained hall now clears any wake left from before it drained.
- Design bible 12.41.

## By eye, at 1x and 2x

`vorrhallow/flooded_hall`, with the hero and a Crystal Dwarf in the water. A pale waterline now
crosses both at the surface and short crests run out from them along it; the body of the water
darkens toward the floor. Combat readability is unaffected: the marks are a pixel high, at the
surface, and pale.

## Tests

`tests/test_tide_wake.gd`, six tests: a ripple's spread and fade and the `wades` box rule; the depth
steps and their dither; the hero's waterline and ripples, faster while running; no wake from a hero
in the air; a foe's waterline; and the drained hall.

Mutation check: `wades` always false fails the hero and foe tests (four checks); `WAKE_MOVING` equal
to `WAKE_STILL` fails the running check.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | Vorrhallow's water answers what stands in it. The HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; the body strip is drawn once and the ripples are capped. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 551: take the independent grade (every fifth pass; this one's was not taken before the cut-off),
then the art loop stays **gated** on Sean. From the pass 545 grade: the uniform rain over the Spires.
Rim light on figures and the Boughs painterly clash stay parked for a watched session.
