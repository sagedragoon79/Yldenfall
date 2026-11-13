# Pass 548: the Sunken Spring is ashlar and deep water

## Category

From the independent grade taken after pass 545 (5.4/10), as pass 547's "Next" named it: "the
Sunken Spring's stone pillars read as striped wallpaper and its water is a flat fill".
Environments, and Atmosphere and lighting, in the grade.

No note from Sean was new. The PixelLab art loop stays **gated** on him: three guardian bases (Haar
Wyrm, Thane Vorrund, Drowned Warden) wait for his OK, the limit of three. No PixelLab generations
were spent. The hosted workbench is still down (its Vercel Blob store is suspended); it stays under
"stuck" for Sean. Pass 546 (#610, the HUD plate, from the project thread) is still an open draft.

## Audit

- `paint_spring` laid two wavy strata per tile, alternating `umber-4` and `umber-3` layer by layer,
  at the same heights in every tile. Down a pillar the layers lined up into continuous horizontal
  bands the width of the wall.
- `SwimWater` drew one translucent teal (alpha 0.42) over each row of water, with a 0.08 darker
  half-row: the whole pool read as one flat colour, in front of everything in it.

## What was built

- **Travertine ashlar** (`paint_spring`, `spring_joints`): two courses per tile, one or two head
  joints per course at seeded positions (4 to 12 world px in, at least 6 apart), one body value with
  a lit top and left and a shadow before each joint, a short pore in some courses and a mineral drip
  from the bed joint in about a third of them. Regenerated `assets/tiles/sunken.png` only.
- **Two-layer water** (`SwimWater`): a body behind the actors that darkens with depth from the
  pool's top in five dithered steps (square-root falloff over 144 px, a strip texture built once),
  and in front a lighter tint (0.2), the waterline, caustics that fade out by 56 px, and bubbles.
- Design bible 12.39; 8.10's swim table updated.

## By eye, at 1x and 2x

`sunken/drowned_aqueduct`, `sunken/wellspring`, `sunken/source_hall`, `sunken/spring_gate`, before
and after, and a scattered 8 x 8 field of the solid variants at 3x. The pillars read as dressed
blocks with staggered joints; the deep interior still sinks into `DeepShade`. A first try that laid
one tall course in some tiles made L-shaped stones where it met two-course neighbours, so it was
dropped. The water is pale just under the surface, with caustics there, and darkens in fine
checkered steps to a deep blue-teal at the floor. The eel and the hero read more clearly through
the lighter front tint.

## Tests

- `tools/art/test_tilegen.py`: `test_paint_spring_is_ashlar_not_stripes` (one body value per course,
  joints spread across the variants, no joint near the tile edge, no sliver);
  `test_paint_spring_wraps_across_the_tile_width` (the seam guard of 12.23, kept). 64 checks pass.
- `tests/test_swim_water_art.gd`, four tests: the dithered steps, the falloff, the caustics, and a
  built pool's layers and its depth under a pillar.

Mutation check: alternating the course value, or fixing the joint x, fails the ashlar test;
dropping the square root fails the falloff test; dropping the dither fails the steps test; measuring
depth from the rock overhead fails the pool test.

## Rubric (design bible 15.3)

| Category | Weight | Score | Notes |
| --- | --- | --- | --- |
| Movement feel | 20 | 99 | Unchanged. |
| Combat and enemies | 15 | 99 | Unchanged; swimmers and eels read better through the lighter tint. |
| World and level design | 15 | 99 | Unchanged; one-template rooms and the empty mid-ground remain. |
| Art cohesion | 15 | 98 | The Sunken pillars are masonry and its water has depth. The HD hero and the guardian bases (gated art loop) remain. |
| Bosses | 10 | 99 | Unchanged. |
| Systems | 10 | 99 | Unchanged. |
| Audio | 5 | 99 | Unchanged. |
| Stability and performance | 5 | 99 | Unchanged; the water's body is drawn once. |
| Story and world | 5 | 99 | Unchanged. |

Weighted: 98.85.

## Next

Pass 549: the art loop stays **gated** on Sean. From the pass 545 grade: glow from the fire seals onto
nearby surfaces, then the Haar's stacked circle lamp lights, then the flat wading-water rectangles in
Vorrhallow. Pass 550 takes an independent grade (every fifth pass). Rim light on figures and the
Boughs painterly clash stay parked for a watched session.
